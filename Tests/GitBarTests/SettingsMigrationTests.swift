@testable import GitBar
import XCTest

@MainActor
final class SettingsMigrationTests: XCTestCase {
    func testCopiesLegacyPreferencesWithoutRemovingThem() {
        let legacy = defaults()
        let current = defaults()
        defer { removeDomain(for: legacy); removeDomain(for: current) }

        legacy.defaults.set(["/tmp/demo-repository"], forKey: "repoPaths_v2")
        legacy.defaults.set("/tmp/demo-repository", forKey: "selectedRepoPath_v2")
        legacy.defaults.set("vscode", forKey: "preferredEditor")

        SettingsService.migrateLegacyPreferences(from: legacy.defaults, to: current.defaults)

        XCTAssertEqual(current.defaults.stringArray(forKey: "repoPaths_v2"), ["/tmp/demo-repository"])
        XCTAssertEqual(current.defaults.string(forKey: "selectedRepoPath_v2"), "/tmp/demo-repository")
        XCTAssertEqual(current.defaults.string(forKey: "preferredEditor"), "vscode")
        XCTAssertEqual(legacy.defaults.string(forKey: "selectedRepoPath_v2"), "/tmp/demo-repository")
    }

    func testCurrentPreferencesTakePrecedence() {
        let legacy = defaults()
        let current = defaults()
        defer { removeDomain(for: legacy); removeDomain(for: current) }

        legacy.defaults.set("/tmp/old", forKey: "selectedRepoPath_v2")
        current.defaults.set("/tmp/current", forKey: "selectedRepoPath_v2")

        SettingsService.migrateLegacyPreferences(from: legacy.defaults, to: current.defaults)

        XCTAssertEqual(current.defaults.string(forKey: "selectedRepoPath_v2"), "/tmp/current")
    }

    func testMigrationDoesNotRestoreLegacyValuesAfterUserClearsThem() {
        let legacy = defaults()
        let current = defaults()
        defer { removeDomain(for: legacy); removeDomain(for: current) }

        legacy.defaults.set(["/tmp/old-repository"], forKey: "repoPaths_v2")
        legacy.defaults.set("/tmp/old-repository", forKey: "selectedRepoPath_v2")
        SettingsService.migrateLegacyPreferences(from: legacy.defaults, to: current.defaults)

        current.defaults.set([], forKey: "repoPaths_v2")
        current.defaults.removeObject(forKey: "selectedRepoPath_v2")
        SettingsService.migrateLegacyPreferences(from: legacy.defaults, to: current.defaults)

        XCTAssertEqual(current.defaults.stringArray(forKey: "repoPaths_v2"), [])
        XCTAssertNil(current.defaults.string(forKey: "selectedRepoPath_v2"))
        XCTAssertTrue(current.defaults.bool(forKey: SettingsService.legacyMigrationCompleteKey))
    }

    private func defaults() -> (domain: String, defaults: UserDefaults) {
        let domain = "com.example.GitBarTests.\(UUID().uuidString)"
        return (domain, UserDefaults(suiteName: domain)!)
    }

    private func removeDomain(for store: (domain: String, defaults: UserDefaults)) {
        store.defaults.removePersistentDomain(forName: store.domain)
    }
}
