@testable import GitBar
import Foundation
import XCTest

@MainActor
final class BranchWorktreeStatusTests: XCTestCase {
    func testDetectsUncommittedChangesForMatchingWorktreeBranch() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        try runGit(["init"], at: path)

        let service = GitService()
        service.worktrees = [Worktree(
            path: path.path,
            branch: "feature",
            commitHash: nil,
            isBare: false,
            isMain: true
        )]

        let cleanFeature = await service.branchHasUncommittedChanges("feature")
        let cleanOther = await service.branchHasUncommittedChanges("other")
        XCTAssertFalse(cleanFeature)
        XCTAssertFalse(cleanOther)

        try Data("local edits".utf8).write(to: path.appendingPathComponent("notes.txt"))

        let dirtyFeature = await service.branchHasUncommittedChanges("feature")
        let dirtyOther = await service.branchHasUncommittedChanges("other")
        XCTAssertTrue(dirtyFeature)
        XCTAssertFalse(dirtyOther)
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
