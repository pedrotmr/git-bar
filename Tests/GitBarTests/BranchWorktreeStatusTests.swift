@testable import GitBar
import Foundation
import XCTest

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
