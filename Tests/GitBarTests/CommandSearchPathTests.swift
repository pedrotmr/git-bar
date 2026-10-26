@testable import GitBar
import XCTest

@MainActor
final class CommandSearchPathTests: XCTestCase {
    func testAddsFinderSearchLocationsAndKeepsExistingEntriesOnce() {
        let path = CommandSearchPath.augmentedPath(
            existingPath: "/custom/bin:/usr/bin:/opt/homebrew/bin",
            homeDirectory: "/Users/example"
        )
        let entries = path.split(separator: ":").map(String.init)

        XCTAssertEqual(entries.prefix(6), [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/Users/example/.local/bin",
            "/Users/example/bin",
        ])
        XCTAssertEqual(entries.filter { $0 == "/usr/bin" }.count, 1)
        XCTAssertEqual(entries.last, "/custom/bin")
    }

    func testFindsSystemGitAndLeavesMissingGitHubCLIActionable() {
        let path = CommandSearchPath.augmentedPath(existingPath: nil, homeDirectory: "/Users/example")

        let gitPath = CommandSearchPath.executablePath(for: "git", path: path)
        XCTAssertNotNil(gitPath)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: gitPath!))
        XCTAssertNil(CommandSearchPath.executablePath(for: "gh", path: "/empty"))
    }

    func testFindsAnExecutableInTheConfiguredPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitbar-path-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("gh")
        XCTAssertTrue(FileManager.default.createFile(
            atPath: executable.path,
            contents: Data("#!/bin/sh\nexit 0\n".utf8),
            attributes: [.posixPermissions: 0o755]
        ))

        XCTAssertEqual(
            CommandSearchPath.executablePath(for: "gh", path: directory.path),
            executable.path
        )
    }

    func testHomebrewInstallMarkerUsesItsOwnPreferencesDomain() {
        let bundleIdentifier = "com.example.GitBarTest.\(UUID().uuidString)"
        let domain = HomebrewInstallDetector.preferencesDomain(for: bundleIdentifier)
        let marker = UserDefaults(suiteName: domain)!
        defer { marker.removePersistentDomain(forName: domain) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, defaults: marker))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, defaults: marker))
        XCTAssertNil(UserDefaults(suiteName: bundleIdentifier)?.object(forKey: HomebrewInstallDetector.markerKey))
    }
}
