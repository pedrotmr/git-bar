@testable import GitBar
import Foundation
import XCTest

private actor SequencedBranchFetcher {
    private let holdsFirstRequest: Bool
    private var requestCount = 0
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var firstRequestReleased = false
    private var firstRequestContinuation: CheckedContinuation<Void, Never>?

    init(holdsFirstRequest: Bool = false) {
        self.holdsFirstRequest = holdsFirstRequest
    }

    func fetch() async -> [Branch] {
        requestCount += 1
        let currentRequest = requestCount
        let readyWaiters = requestWaiters.filter { $0.count <= currentRequest }
        requestWaiters.removeAll { $0.count <= currentRequest }
        readyWaiters.forEach { $0.continuation.resume() }

        if currentRequest == 1 {
            if holdsFirstRequest && !firstRequestReleased {
                await withCheckedContinuation { firstRequestContinuation = $0 }
            }
            return [Branch(name: "stale", isCurrent: false)]
        }
        return [Branch(name: "fresh", isCurrent: false)]
    }

    func waitForRequest(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append((count, continuation))
        }
    }

    func releaseFirstRequest() {
        firstRequestReleased = true
        firstRequestContinuation?.resume()
        firstRequestContinuation = nil
    }
}

private actor CheckoutGate {
    private var checkoutStarted = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func pauseUntilReleased() async {
        checkoutStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        guard !released else { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }

    func waitForCheckoutStart() async {
        guard !checkoutStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor
final class BranchWorktreeStatusTests: XCTestCase {
    func testDetectsUncommittedChangesForWorktreePath() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        try runGit(["init"], at: path)

        let service = GitService()
        let clean = await service.hasUncommittedChanges(path.path)
        XCTAssertFalse(clean)

        try Data("local edits".utf8).write(to: path.appendingPathComponent("notes.txt"))

        let dirty = await service.hasUncommittedChanges(path.path)
        XCTAssertTrue(dirty)
    }

    func testRequiresDeleteConfirmationWhenWorktreeStatusIsUnavailable() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        let service = GitService()
        service.worktrees = [Worktree(
            path: path.path,
            branch: "feature",
            commitHash: nil,
            isBare: false,
            isMain: true
        )]

        let needsConfirmation = await service.branchNeedsDeleteConfirmation("feature")
        XCTAssertTrue(needsConfirmation)
    }

    func testStaleSilentRefreshCannotReplaceANewerRefreshForSameRepository() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarRefreshTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        let fetcher = SequencedBranchFetcher(holdsFirstRequest: true)
        let service = GitService(branchFetcher: { _ in await fetcher.fetch() })
        service.selectRepository(path.path)

        let staleRefresh = Task { await service.refreshSilently() }
        await fetcher.waitForRequest(1)
        await service.refresh()
        XCTAssertEqual(service.branches.map(\.name), ["fresh"])
        await fetcher.releaseFirstRequest()
        await staleRefresh.value

        XCTAssertEqual(service.branches.map(\.name), ["fresh"])
    }

    func testStaleRefreshCannotReplaceDataAfterSwitchingAwayAndBack() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarRefreshTests-\(UUID().uuidString)", isDirectory: true)
        let firstPath = root.appendingPathComponent("first", isDirectory: true)
        let secondPath = root.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fetcher = SequencedBranchFetcher(holdsFirstRequest: true)
        let service = GitService(branchFetcher: { _ in await fetcher.fetch() })
        service.selectRepository(firstPath.path)

        let staleRefresh = Task { await service.refresh() }
        await fetcher.waitForRequest(1)
        service.selectRepository(secondPath.path)
        service.selectRepository(firstPath.path)
        await service.refresh()
        await fetcher.releaseFirstRequest()
        await staleRefresh.value

        XCTAssertEqual(service.branches.map(\.name), ["fresh"])
    }

    func testSuccessfulMutationInvalidatesAnOlderRefresh() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarMutationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        let fetcher = SequencedBranchFetcher(holdsFirstRequest: true)
        let checkoutGate = CheckoutGate()
        let service = GitService(
            branchFetcher: { _ in await fetcher.fetch() },
            checkoutPullRequest: { _, _ in await checkoutGate.pauseUntilReleased() }
        )
        service.selectRepository(path.path)
        let pullRequest = PullRequest(
            number: 42,
            title: "Feature branch",
            headRefName: "feature",
            url: "https://github.com/owner/repo/pull/42",
            category: .assigned
        )

        let checkout = Task { await service.checkoutPRBranch(pullRequest) }
        await checkoutGate.waitForCheckoutStart()
        let olderRefresh = Task { await service.refresh() }
        await fetcher.waitForRequest(1)

        await checkoutGate.release()
        await checkout.value
        await fetcher.waitForRequest(2)
        await fetcher.releaseFirstRequest()
        await olderRefresh.value

        XCTAssertEqual(service.branches.map(\.name), ["fresh"])
    }

    func testCheckoutRefreshUsesCurrentGenerationAfterInterveningRefresh() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarMutationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        let fetcher = SequencedBranchFetcher()
        let checkoutGate = CheckoutGate()
        let service = GitService(
            branchFetcher: { _ in await fetcher.fetch() },
            checkoutPullRequest: { _, _ in await checkoutGate.pauseUntilReleased() }
        )
        service.selectRepository(path.path)
        let pullRequest = PullRequest(
            number: 42,
            title: "Feature branch",
            headRefName: "feature",
            url: "https://github.com/owner/repo/pull/42",
            category: .assigned
        )

        let checkout = Task { await service.checkoutPRBranch(pullRequest) }
        await checkoutGate.waitForCheckoutStart()
        await service.refresh()
        XCTAssertEqual(service.branches.map(\.name), ["stale"])

        await checkoutGate.release()
        await checkout.value

        XCTAssertEqual(service.branches.map(\.name), ["fresh"])
    }

    private func runGit(_ arguments: [String], at path: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = path
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "BranchWorktreeStatusTests", code: Int(process.terminationStatus))
        }
    }
}
