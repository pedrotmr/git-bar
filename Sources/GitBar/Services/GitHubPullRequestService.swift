import Foundation

struct PullRequestFetchResult {
    let pullRequests: [PullRequest]
    let errorMessage: String?
}

@MainActor
final class GitHubPullRequestService {
    private struct RepositoryContext {
        var ownerAndRepository: String?
        var username: String?
        var hasReportedCLIError = false
    }

    private struct GHUser: Decodable {
        let login: String
    }

    private struct GHReviewRequest: Decodable {
        let requestedReviewer: GHUser?

        enum CodingKeys: String, CodingKey { case requestedReviewer }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            requestedReviewer = try? container.decodeIfPresent(GHUser.self, forKey: .requestedReviewer)
        }
    }

    private struct GHPRResponse: Decodable {
        let number: Int
        let title: String
        let headRefName: String
        let url: String
        let author: GHUser
        let assignees: [GHUser]
        let reviewRequests: [GHReviewRequest]
    }

    private struct GHPRSimple: Decodable {
        let number: Int
    }

    private var contexts: [String: RepositoryContext] = [:]

    func fetchPullRequests(in repositoryPath: String) async -> PullRequestFetchResult {
        let key = (repositoryPath as NSString).standardizingPath
        let (result, context) = await fetchPullRequests(
            in: repositoryPath,
            context: contexts[key] ?? RepositoryContext()
        )
        contexts[key] = context
        return result
    }

    func checkoutPullRequest(_ pullRequest: PullRequest, at repositoryPath: String) async throws {
        let result = await ShellExecutor.run(
            "gh",
            Self.checkoutArguments(for: pullRequest),
            at: repositoryPath
        )
        guard result.exitCode == 0 else {
            let message = Self.actionableCLIMessage(for: result)
            throw GitCommandFailure(
                message: message.isEmpty ? "GitHub CLI failed to check out pull request #\(pullRequest.number)." : message,
                exitCode: result.exitCode,
                hasDiagnostic: !result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    static func checkoutArguments(for pullRequest: PullRequest) -> [String] {
        ["pr", "checkout", String(pullRequest.number)]
    }

    static func actionableCLIMessage(for result: ShellResult) -> String {
        let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.commandNotFound else { return message }
        return "\(message) Install GitHub CLI with `brew install gh` and sign in with `gh auth login`."
    }

    private func fetchPullRequests(
        in repositoryPath: String,
        context initialContext: RepositoryContext
    ) async -> (PullRequestFetchResult, RepositoryContext) {
        var context = initialContext
        let ownerAndRepository: String
        if let cached = context.ownerAndRepository {
            ownerAndRepository = cached
        } else {
            let remoteResult = await ShellExecutor.run(
                ["remote", "get-url", "origin"],
                at: repositoryPath
            )
            guard remoteResult.exitCode == 0,
                  let parsed = Self.parseGitHubOwnerAndRepository(
                    from: remoteResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                  )
            else {
                return (PullRequestFetchResult(pullRequests: [], errorMessage: nil), context)
            }
            context.ownerAndRepository = parsed
            ownerAndRepository = parsed
        }

        let username: String
        if let cached = context.username {
            username = cached
        } else {
            let userResult = await ShellExecutor.run(
                "gh",
                ["api", "user", "--jq", ".login"],
                at: repositoryPath
            )
            guard userResult.exitCode == 0 else {
                let displayMessage = Self.reportableCLIError(for: userResult, context: &context)
                return (PullRequestFetchResult(pullRequests: [], errorMessage: displayMessage), context)
            }

            let resolved = userResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolved.isEmpty else {
                return (PullRequestFetchResult(pullRequests: [], errorMessage: nil), context)
            }
            context.username = resolved
            context.hasReportedCLIError = false
            username = resolved
        }

        async let pullRequestResult = ShellExecutor.run(
            "gh",
            [
                "pr", "list",
                "--repo", ownerAndRepository,
                "--state", "open",
                "--json", "number,title,headRefName,url,author,assignees,reviewRequests",
                "--limit", "100",
            ],
            at: repositoryPath
        )
        async let reviewRequestResult = ShellExecutor.run(
            "gh",
            [
                "pr", "list",
                "--repo", ownerAndRepository,
                "--state", "open",
                "--search", "review-requested:@me",
                "--json", "number",
                "--limit", "500",
            ],
            at: repositoryPath
        )

        let (pullRequestOutput, reviewRequestOutput) = await (pullRequestResult, reviewRequestResult)
        guard pullRequestOutput.exitCode == 0 else {
            let error = Self.reportableCLIError(for: pullRequestOutput, context: &context)
            return (PullRequestFetchResult(pullRequests: [], errorMessage: error), context)
        }
        guard let data = pullRequestOutput.stdout.data(using: .utf8) else {
            return (
                PullRequestFetchResult(pullRequests: [], errorMessage: "GitHub CLI returned invalid PR output."),
                context
            )
        }

        let rawPullRequests: [GHPRResponse]
        do {
            rawPullRequests = try JSONDecoder().decode([GHPRResponse].self, from: data)
        } catch {
            return (
                PullRequestFetchResult(
                    pullRequests: [],
                    errorMessage: "Failed to parse PRs: \(error.localizedDescription)"
                ),
                context
            )
        }

        let (reviewRequestedNumbers, reviewError) = Self.reviewRequestedNumbers(from: reviewRequestOutput)
        let pullRequests = Self.categorize(
            rawPullRequests,
            username: username,
            reviewRequestedNumbers: reviewRequestedNumbers
        )
        return (
            PullRequestFetchResult(pullRequests: pullRequests, errorMessage: reviewError),
            context
        )
    }

    private static func reviewRequestedNumbers(from result: ShellResult) -> (Set<Int>, String?) {
        guard result.exitCode == 0,
              let data = result.stdout.data(using: .utf8)
        else { return ([], nil) }

        do {
            let response = try JSONDecoder().decode([GHPRSimple].self, from: data)
            return (Set(response.map(\.number)), nil)
        } catch {
            return ([], "Failed to parse team review requests: \(error.localizedDescription)")
        }
    }

    private static func reportableCLIError(
        for result: ShellResult,
        context: inout RepositoryContext
    ) -> String? {
        guard !context.hasReportedCLIError else { return nil }
        let message = actionableCLIMessage(for: result)
        context.hasReportedCLIError = true
        return "GitHub CLI: \(message.isEmpty ? "Command failed with exit code \(result.exitCode)." : message)"
    }

    private static func categorize(
        _ pullRequests: [GHPRResponse],
        username: String,
        reviewRequestedNumbers: Set<Int>
    ) -> [PullRequest] {
        var created = [PullRequest]()
        var assigned = [PullRequest]()
        var reviewRequested = [PullRequest]()

        for pr in pullRequests {
            let category: PRCategory?
            if pr.author.login == username {
                category = .created
            } else if pr.assignees.contains(where: { $0.login == username }) {
                category = .assigned
            } else if pr.reviewRequests.contains(where: { $0.requestedReviewer?.login == username })
                        || reviewRequestedNumbers.contains(pr.number) {
                category = .reviewRequested
            } else {
                category = nil
            }

            guard let category else { continue }
            let result = PullRequest(
                number: pr.number,
                title: pr.title,
                headRefName: pr.headRefName,
                url: pr.url,
                category: category
            )
            switch category {
            case .created: created.append(result)
            case .assigned: assigned.append(result)
            case .reviewRequested: reviewRequested.append(result)
            }
        }

        return created + assigned + reviewRequested
    }

    static func parseGitHubOwnerAndRepository(from remoteURL: String) -> String? {
        let raw: String
        if remoteURL.hasPrefix("git@github.com:") {
            raw = String(remoteURL.dropFirst("git@github.com:".count))
        } else {
            guard let components = URLComponents(string: remoteURL),
                  components.host?.caseInsensitiveCompare("github.com") == .orderedSame,
                  ["https", "http", "ssh"].contains(components.scheme?.lowercased() ?? "")
            else { return nil }
            raw = String(components.path.dropFirst(components.path.hasPrefix("/") ? 1 : 0))
        }

        let path = raw.hasSuffix(".git") ? String(raw.dropLast(4)) : raw
        let parts = path.split(separator: "/")
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { return nil }
        return parts.map(String.init).joined(separator: "/")
    }
}
