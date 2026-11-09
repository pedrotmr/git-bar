import Foundation
import Observation

private struct RepoSnapshot {
    let branches: [Branch]
    let worktrees: [Worktree]
    let stashes: [Stash]
    let pullRequests: [PullRequest]
}

@MainActor
@Observable
class GitService {
    var repoPath: String = "" {
        didSet {
            guard oldValue != repoPath else {
                setupWatcher()
                return
            }
            selectionGeneration += 1
            refreshGeneration += 1
            isLoading = false
            if !oldValue.isEmpty { persistSnapshot(for: oldValue) }
            applyRepoSelection(path: repoPath)
            setupWatcher()
        }
    }
    var branches: [Branch] = []
    var worktrees: [Worktree] = []
    var stashes: [Stash] = []
    var pullRequests: [PullRequest] = []
    var isLoading = false
    var errorMessage: String?
    var isDirty = false
    var isPopoverVisible = false {
        didSet {
            if isPopoverVisible { Task { await refreshIfNeeded() } }
        }
    }
    var autoFetchEnabled = false {
        didSet { autoFetchEnabled ? startFetchTimer() : stopFetchTimer() }
    }

    private let repositoryClient: GitRepositoryClient
    private let branchFetcher: (String) async throws -> [Branch]
    private let pullRequestService: GitHubPullRequestService
    private let checkoutPullRequest: (PullRequest, String) async throws -> Void
    private var watcher: GitRepositoryWatcher?
    private var fetchTimer: Timer?
    private var isMutating = false
    private var refreshGeneration = 0
    private var selectionGeneration = 0
    private var restoredFromCache = false
    private var awaitingFirstFetch = false
    private var repoCache: [String: RepoSnapshot] = [:]

    init(
        branchFetcher: ((String) async throws -> [Branch])? = nil,
        checkoutPullRequest: ((PullRequest, String) async throws -> Void)? = nil
    ) {
        let repositoryClient = GitRepositoryClient()
        let pullRequestService = GitHubPullRequestService()
        self.repositoryClient = repositoryClient
        self.pullRequestService = pullRequestService
        self.branchFetcher = branchFetcher ?? { path in
            try await repositoryClient.branches(at: path)
        }
        self.checkoutPullRequest = checkoutPullRequest ?? { pullRequest, path in
            try await pullRequestService.checkoutPullRequest(pullRequest, at: path)
        }
    }

    private func cacheKey(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private func persistSnapshot(for path: String) {
        let key = cacheKey(path)
        guard !key.isEmpty else { return }
        repoCache[key] = RepoSnapshot(
            branches: branches,
            worktrees: worktrees,
            stashes: stashes,
            pullRequests: pullRequests
        )
    }

    private func applyRepoSelection(path: String) {
        restoredFromCache = false
        awaitingFirstFetch = false
        guard !path.isEmpty else {
            clearRepositoryData()
            return
        }

        if let snapshot = repoCache[cacheKey(path)] {
            branches = snapshot.branches
            worktrees = snapshot.worktrees
            stashes = snapshot.stashes
            pullRequests = snapshot.pullRequests
            restoredFromCache = true
        } else {
            clearRepositoryData()
            awaitingFirstFetch = true
        }
    }

    func selectRepository(_ path: String?) {
        guard let path else {
            repoPath = ""
            errorMessage = nil
            return
        }
        repoPath = path
        isDirty = true
    }

    private func clearRepositoryData() {
        branches = []
        worktrees = []
        stashes = []
        pullRequests = []
    }

    private func runFullFetch(at path: String, generation: Int) async {
        async let branches: Void = fetchBranches(at: path, generation: generation)
        async let worktrees: Void = fetchWorktrees(at: path, generation: generation)
        async let stashes: Void = fetchStashes(at: path, generation: generation)
        async let pullRequests: Void = fetchPullRequests(at: path, generation: generation)
        _ = await (branches, worktrees, stashes, pullRequests)
    }

    func refresh() async {
        let path = repoPath
        guard !path.isEmpty else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        errorMessage = nil
        await runFullFetch(at: path, generation: generation)
        guard refreshGeneration == generation, repoPath == path else { return }
        isLoading = false
        awaitingFirstFetch = false
        persistSnapshot(for: path)
    }

    func refreshSilently(expectedSelectionGeneration: Int? = nil) async {
        let path = repoPath
        guard !path.isEmpty,
              expectedSelectionGeneration == nil || expectedSelectionGeneration == selectionGeneration
        else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        errorMessage = nil
        await runFullFetch(at: path, generation: generation)
        guard refreshGeneration == generation,
              repoPath == path,
              expectedSelectionGeneration == nil || expectedSelectionGeneration == selectionGeneration
        else { return }
        isLoading = false
        awaitingFirstFetch = false
        persistSnapshot(for: path)
    }

    func refreshAfterRepoSelection() async {
        let path = repoPath
        guard !path.isEmpty else { return }
        let fromCache = restoredFromCache
        restoredFromCache = false
        isDirty = false
        if fromCache {
            await refreshSilently()
        } else {
            await refresh()
        }
    }

    private func fetchBranches(at path: String, generation: Int) async {
        do {
            let fetched = try await branchFetcher(path)
            guard refreshGeneration == generation, repoPath == path else { return }
            branches = fetched
        } catch {
            guard refreshGeneration == generation, repoPath == path else { return }
            appendError(error.localizedDescription)
        }
    }

    private func fetchWorktrees(at path: String, generation: Int) async {
        do {
            let fetched = try await repositoryClient.worktrees(at: path)
            guard refreshGeneration == generation, repoPath == path else { return }
            worktrees = fetched
        } catch {
            guard refreshGeneration == generation, repoPath == path else { return }
            appendError(error.localizedDescription)
        }
    }

    private func fetchStashes(at path: String, generation: Int) async {
        do {
            let fetched = try await repositoryClient.stashes(at: path)
            guard refreshGeneration == generation, repoPath == path else { return }
            stashes = fetched
        } catch {
            guard refreshGeneration == generation, repoPath == path else { return }
            appendError(error.localizedDescription)
        }
    }

    private func fetchPullRequests(at path: String, generation: Int) async {
        let result = await pullRequestService.fetchPullRequests(in: path)
        guard refreshGeneration == generation, repoPath == path else { return }
        pullRequests = result.pullRequests
        if let error = result.errorMessage { appendError(error) }
    }

    private func isCurrentSelection(path: String, generation: Int) -> Bool {
        selectionGeneration == generation && repoPath == path
    }

    private func refreshBranchesAfterMutation(at path: String, selectionGeneration: Int) async {
        guard isCurrentSelection(path: path, generation: selectionGeneration) else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        await fetchBranches(at: path, generation: generation)
        if refreshGeneration == generation { isLoading = false }
    }

    private func refreshStashesAfterMutation(at path: String, selectionGeneration: Int) async {
        guard isCurrentSelection(path: path, generation: selectionGeneration) else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        await fetchStashes(at: path, generation: generation)
        if refreshGeneration == generation { isLoading = false }
    }

    private func appendError(_ message: String) {
        if let existing = errorMessage {
            errorMessage = existing + "\n" + message
        } else {
            errorMessage = message
        }
    }

    func checkoutPRBranch(_ pr: PullRequest) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            do {
                try await checkoutPullRequest(pr, path)
                await refreshBranchesAfterMutation(at: path, selectionGeneration: selectedGeneration)
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func switchBranch(_ name: String) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            do {
                try await repositoryClient.checkoutBranch(name, at: path)
                await refreshBranchesAfterMutation(at: path, selectionGeneration: selectedGeneration)
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func pullCurrentBranch() async {
        guard let currentBranch = branches.first(where: \.isCurrent), currentBranch.upstream != nil else { return }
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            errorMessage = nil
            do {
                try await repositoryClient.pullCurrentBranch(at: path)
                if isCurrentSelection(path: path, generation: selectedGeneration) {
                    await refreshSilently(expectedSelectionGeneration: selectedGeneration)
                }
            } catch let error as GitCommandFailure where !error.hasDiagnostic {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = "Could not pull updates (exit code \(error.exitCode))."
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteBranch(_ name: String, force: Bool = false) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            errorMessage = nil
            do {
                try await repositoryClient.deleteBranch(name, force: force, at: path)
                await refreshBranchesAfterMutation(at: path, selectionGeneration: selectedGeneration)
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteLocalAndRemoteBranch(_ name: String) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            errorMessage = nil
            let result = await repositoryClient.deleteLocalAndRemoteBranch(name, at: path)
            guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
            if let remoteError = result.remoteError, !remoteError.isEmpty {
                appendError("Remote deletion failed: \(remoteError)")
            }
            if result.deletedLocally {
                await refreshBranchesAfterMutation(at: path, selectionGeneration: selectedGeneration)
            } else if let localError = result.localError {
                appendError(localError)
            }
        }
    }

    func deleteWorktreeAndBranch(_ worktree: Worktree) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            do {
                try await repositoryClient.deleteWorktreeAndBranch(worktree, at: path)
                if isCurrentSelection(path: path, generation: selectedGeneration) {
                    await refreshSilently(expectedSelectionGeneration: selectedGeneration)
                }
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func applyStash(_ ref: String) async {
        await runStashCommand(.apply, ref: ref)
    }

    func popStash(_ ref: String) async {
        await runStashCommand(.pop, ref: ref)
    }

    func dropStash(_ ref: String) async {
        await runStashCommand(.drop, ref: ref)
    }

    private func runStashCommand(_ operation: StashOperation, ref: String) async {
        let path = repoPath
        let selectedGeneration = selectionGeneration
        await withMutation {
            errorMessage = nil
            do {
                try await repositoryClient.runStash(operation, ref: ref, at: path)
                await refreshStashesAfterMutation(at: path, selectionGeneration: selectedGeneration)
                if isCurrentSelection(path: path, generation: selectedGeneration) { persistSnapshot(for: path) }
            } catch {
                guard isCurrentSelection(path: path, generation: selectedGeneration) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func withMutation(_ operation: () async -> Void) async {
        guard !isMutating else { return }
        isMutating = true
        defer { isMutating = false }
        await operation()
    }

    func hasUncommittedChanges(_ path: String) async -> Bool {
        await repositoryClient.worktreeChangeStatus(at: path) == .changed
    }

    func branchNeedsDeleteConfirmation(_ branchName: String) async -> Bool {
        guard let worktree = worktrees.first(where: { $0.branch == branchName }) else { return false }
        return await repositoryClient.worktreeChangeStatus(at: worktree.path) != .clean
    }

    func isGitRepo(_ path: String) async -> Bool {
        await repositoryClient.isGitRepository(at: path)
    }

    func refreshIfNeeded() async {
        guard isDirty else { return }
        isDirty = false
        if awaitingFirstFetch {
            await refresh()
        } else {
            await refreshSilently()
        }
    }

    private func setupWatcher() {
        watcher?.stop()
        guard !repoPath.isEmpty else {
            watcher = nil
            return
        }
        let watchedPath = repoPath
        watcher = GitRepositoryWatcher { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.repoPath == watchedPath else { return }
                self.isDirty = true
            }
        }
        watcher?.start(repoPath: repoPath)
    }

    private func startFetchTimer() {
        stopFetchTimer()
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let service = self else { return }
            Task { @MainActor in await service.performFetch() }
        }
    }

    private func stopFetchTimer() {
        fetchTimer?.invalidate()
        fetchTimer = nil
    }

    private func performFetch() async {
        let path = repoPath
        guard !path.isEmpty else { return }
        do {
            try await repositoryClient.fetchAll(at: path)
        } catch let error as GitCommandFailure where !error.hasDiagnostic {
            guard repoPath == path else { return }
            errorMessage = "Auto-fetch failed: Unknown error (exit code \(error.exitCode))"
            return
        } catch {
            guard repoPath == path else { return }
            errorMessage = "Auto-fetch failed: \(error.localizedDescription)"
            return
        }
        guard repoPath == path else { return }
        if isPopoverVisible {
            await refreshSilently()
        } else {
            isDirty = true
        }
    }
}
