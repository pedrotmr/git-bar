import Foundation

nonisolated struct GitCommandFailure: LocalizedError {
    let message: String
    let exitCode: Int32
    let hasDiagnostic: Bool

    var errorDescription: String? { message }
}

nonisolated enum WorktreeChangeStatus: Equatable {
    case clean
    case changed
    case unavailable
}

nonisolated enum StashOperation: String {
    case apply
    case pop
    case drop
}

nonisolated struct LocalAndRemoteBranchDeletion {
    let remoteError: String?
    let localError: String?

    var deletedLocally: Bool { localError == nil }
}

nonisolated struct GitRepositoryClient {
    func branches(at path: String) async throws -> [Branch] {
        let stdout = try await output(
            ["branch", "--format=%(refname:short)%09%(HEAD)%09%(upstream:short)%09%(upstream:track,nobracket)"],
            at: path,
            environmentOverrides: ["LC_ALL": "C"]
        )
        return stdout
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard let name = parts.first, !name.isEmpty else { return nil }
                let tracking = parts.count > 3 ? String(parts[3]) : ""
                let upstream = parts.count > 2 && !parts[2].isEmpty && tracking != "gone"
                    ? String(parts[2])
                    : nil
                return Branch(
                    name: String(name),
                    isCurrent: parts.count > 1 && parts[1] == "*",
                    upstream: upstream,
                    ahead: Self.trackingCount("ahead", in: tracking),
                    behind: Self.trackingCount("behind", in: tracking)
                )
            }
    }

    func worktrees(at path: String) async throws -> [Worktree] {
        let stdout = try await output(["worktree", "list", "--porcelain"], at: path)
        var parsed: [Worktree] = []
        var isFirst = true

        for stanza in stdout.components(separatedBy: "\n\n") {
            let lines = stanza.split(separator: "\n").map(String.init)
            guard !lines.isEmpty else { continue }

            var worktreePath: String?
            var branch: String?
            var commit: String?
            var isBare = false

            for line in lines {
                if line.hasPrefix("worktree ") {
                    worktreePath = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("HEAD ") {
                    commit = String(line.dropFirst("HEAD ".count))
                } else if line.hasPrefix("branch refs/heads/") {
                    branch = String(line.dropFirst("branch refs/heads/".count))
                } else if line == "bare" {
                    isBare = true
                }
            }

            if let worktreePath {
                parsed.append(Worktree(
                    path: worktreePath,
                    branch: branch,
                    commitHash: commit,
                    isBare: isBare,
                    isMain: isFirst
                ))
                isFirst = false
            }
        }
        return parsed
    }

    func stashes(at path: String) async throws -> [Stash] {
        let stdout = try await output(["stash", "list", "--format=%gd%x1f%gs"], at: path)
        return stdout
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "\u{1f}", maxSplits: 1).map(String.init)
                guard let ref = parts.first, !ref.isEmpty else { return nil }
                return Stash(ref: ref, message: parts.count == 2 ? parts[1] : "")
            }
    }

    func isGitRepository(at path: String) async -> Bool {
        let result = await run(["rev-parse", "--is-inside-work-tree"], at: path)
        return result.exitCode == 0
    }

    func worktreeChangeStatus(at path: String) async -> WorktreeChangeStatus {
        let result = await run(["status", "--porcelain"], at: path)
        guard result.exitCode == 0 else { return .unavailable }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clean : .changed
    }

    func checkoutBranch(_ name: String, at path: String) async throws {
        _ = try await output(["checkout", name], at: path)
    }

    func pullCurrentBranch(at path: String) async throws {
        _ = try await output(["pull", "--ff-only"], at: path)
    }

    func deleteBranch(_ name: String, force: Bool, at path: String) async throws {
        _ = try await output(["branch", force ? "-D" : "-d", name], at: path)
    }

    func deleteLocalAndRemoteBranch(_ name: String, at path: String) async -> LocalAndRemoteBranchDeletion {
        let remote = await run(["push", "origin", "--delete", name], at: path)
        let local = await run(["branch", "-D", name], at: path)
        return LocalAndRemoteBranchDeletion(
            remoteError: remote.exitCode == 0 ? nil : Self.message(from: remote),
            localError: local.exitCode == 0 ? nil : Self.message(from: local)
        )
    }

    func deleteWorktreeAndBranch(_ worktree: Worktree, at path: String) async throws {
        _ = try await output(["worktree", "remove", "--force", worktree.path], at: path)
        if let branch = worktree.branch {
            _ = try await output(["branch", "-D", branch], at: path)
        }
    }

    func runStash(_ operation: StashOperation, ref: String, at path: String) async throws {
        _ = try await output(["stash", operation.rawValue, ref], at: path)
    }

    func fetchAll(at path: String) async throws {
        _ = try await output(["fetch", "--all", "--quiet"], at: path, timeout: 60)
    }

    private func output(
        _ args: [String],
        at path: String,
        timeout: TimeInterval = ShellExecutor.defaultTimeout,
        environmentOverrides: [String: String] = [:]
    ) async throws -> String {
        let result = await run(args, at: path, timeout: timeout, environmentOverrides: environmentOverrides)
        guard result.exitCode == 0 else {
            throw GitCommandFailure(
                message: Self.message(from: result),
                exitCode: result.exitCode,
                hasDiagnostic: !result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        return result.stdout
    }

    private func run(
        _ args: [String],
        at path: String,
        timeout: TimeInterval = ShellExecutor.defaultTimeout,
        environmentOverrides: [String: String] = [:]
    ) async -> ShellResult {
        await ShellExecutor.run(args, at: path, timeout: timeout, environmentOverrides: environmentOverrides)
    }

    private static func message(from result: ShellResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return stderr.isEmpty ? "Git command failed (exit code \(result.exitCode))." : stderr
    }

    private static func trackingCount(_ direction: String, in tracking: String) -> Int {
        let pattern = "(?:^|, )\(direction) ([0-9]+)(?:$|, )"
        guard let range = tracking.range(of: pattern, options: .regularExpression),
              let numberRange = tracking[range].range(of: "[0-9]+", options: .regularExpression)
        else { return 0 }
        return Int(tracking[numberRange]) ?? 0
    }
}
