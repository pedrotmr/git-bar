@testable import GitBar
import XCTest
import Sparkle

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

    func testFindsSystemGitAndLeavesMissingGitHubCLIActionable() throws {
        let path = CommandSearchPath.augmentedPath(existingPath: nil, homeDirectory: "/Users/example")

        let gitPath = try XCTUnwrap(CommandSearchPath.executablePath(for: "git", path: path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: gitPath))
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
        let bundleURL = URL(fileURLWithPath: "/Applications/GitBar.app")
        defer { marker.removePersistentDomain(forName: domain) }

        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL, defaults: marker))
        marker.set(true, forKey: HomebrewInstallDetector.markerKey)
        marker.set("1.0", forKey: HomebrewInstallDetector.versionKey)
        marker.set(bundleURL.path, forKey: HomebrewInstallDetector.bundlePathKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL, defaults: marker))
        marker.set("2.0", forKey: HomebrewInstallDetector.versionKey)
        XCTAssertTrue(HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL, defaults: marker))
        XCTAssertFalse(HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            bundleURL: URL(fileURLWithPath: "/Users/example/Downloads/GitBar.app"),
            defaults: marker
        ))
        XCTAssertNil(UserDefaults(suiteName: bundleIdentifier)?.object(forKey: HomebrewInstallDetector.markerKey))
    }

    func testUpdateCheckPolicyAllowsUserAndInformationChecksButBlocksScheduledChecks() {
        XCTAssertTrue(UpdateCheckPolicy.allows(.updates))
        XCTAssertTrue(UpdateCheckPolicy.allows(.updateInformation))
        XCTAssertFalse(UpdateCheckPolicy.allows(.updatesInBackground))
    }

    func testUpdateProbeScheduleRetriesTransientFailuresAndThenReturnsToNormalInterval() {
        var schedule = UpdateProbeSchedule()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        for _ in 0..<UpdateProbeSchedule.maximumRetries {
            XCTAssertEqual(schedule.nextInterval(after: error, normalInterval: 86_400), UpdateProbeSchedule.retryInterval)
        }

        XCTAssertEqual(schedule.nextInterval(after: error, normalInterval: 86_400), 86_400)
        XCTAssertEqual(schedule.consecutiveRetries, 0)
    }

    func testNoUpdateIsACompletedProbeAndResetsRetryCount() {
        var schedule = UpdateProbeSchedule()
        let noUpdateError = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue))
        let transientError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        _ = schedule.nextInterval(after: transientError, normalInterval: 86_400)

        XCTAssertEqual(schedule.nextInterval(after: noUpdateError, normalInterval: 86_400), 86_400)
        XCTAssertEqual(schedule.consecutiveRetries, 0)
    }
}
