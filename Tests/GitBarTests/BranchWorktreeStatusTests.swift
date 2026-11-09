@testable import GitBar
import Foundation
import XCTest

private actor SequencedBranchFetcher {
    private var requestCount = 0
    private var firstRequestStarted = false
    private var firstRequestWaiters: [CheckedContinuation<Void, Never>] = []

    func fetch() async -> [Branch] {
        requestCount += 1
        if requestCount == 1 {
            firstRequestStarted = true
            firstRequestWaiters.forEach { $0.resume() }
            firstRequestWaiters.removeAll()
            try? await Task.sleep(nanoseconds: 200_000_000)
            return [Branch(name: "stale", isCurrent: false)]
        }
        return [Branch(name: "fresh", isCurrent: false)]
    }

    func waitForFirstRequest() async {
        guard !firstRequestStarted else { return }
        await withCheckedContinuation { continuation in
            firstRequestWaiters.append(continuation)
        }
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

        let fetcher = SequencedBranchFetcher()
        let service = GitService(branchFetcher: { _ in await fetcher.fetch() })
        service.selectRepository(path.path)

        let staleRefresh = Task { await service.refreshSilently() }
        await fetcher.waitForFirstRequest()
        await service.refresh()
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

        let fetcher = SequencedBranchFetcher()
        let service = GitService(branchFetcher: { _ in await fetcher.fetch() })
        service.selectRepository(firstPath.path)

        let staleRefresh = Task { await service.refresh() }
        await fetcher.waitForFirstRequest()
        service.selectRepository(secondPath.path)
        service.selectRepository(firstPath.path)
        await service.refresh()
        await staleRefresh.value

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
