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
        legacy.defaults.set(false, forKey: "confirmBranchDeletion")

        SettingsService.migrateLegacyPreferences(from: legacy.defaults, to: current.defaults)

        XCTAssertEqual(current.defaults.stringArray(forKey: "repoPaths_v2"), ["/tmp/demo-repository"])
        XCTAssertEqual(current.defaults.string(forKey: "selectedRepoPath_v2"), "/tmp/demo-repository")
        XCTAssertEqual(current.defaults.string(forKey: "preferredEditor"), "vscode")
        XCTAssertEqual(current.defaults.object(forKey: "confirmBranchDeletion") as? Bool, false)
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

    func testTabVisibilityPersistsUsingTheExistingPreferenceKey() {
        let store = defaults()
        defer { removeDomain(for: store) }

        let settings = SettingsService(defaults: store.defaults, legacyDefaults: nil)
        XCTAssertTrue(settings.isTabVisible(.branches))

        settings.setTabVisible(false, for: .branches)

        XCTAssertEqual(store.defaults.object(forKey: "showBranchesTab") as? Bool, false)
        XCTAssertFalse(SettingsService(defaults: store.defaults, legacyDefaults: nil).isTabVisible(.branches))
    }

    func testTabCasesMatchTheDefaultSettingsOrder() {
        XCTAssertEqual(AppTab.allCases, AppTab.defaultOrder)
    }

    func testRepositoryPathShorteningRequiresAHomeDirectoryBoundary() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        XCTAssertEqual(RepositoryLocation(path: home).shortenedPath, "~")
        XCTAssertEqual(RepositoryLocation(path: home + "/repo").shortenedPath, "~/repo")
        XCTAssertEqual(RepositoryLocation(path: home + "2/repo").shortenedPath, home + "2/repo")
    }

    func testRepositoryAndTabReorderingPersistTheirCurrentOrder() {
        let store = defaults()
        defer { removeDomain(for: store) }

        let settings = SettingsService(defaults: store.defaults, legacyDefaults: nil)
        settings.addRepo("/tmp/first")
        settings.addRepo("/tmp/second")
        settings.addRepo("/tmp/third")
        settings.moveRepo(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        settings.moveTab(from: .branches, onto: .pullRequests)

        XCTAssertEqual(store.defaults.stringArray(forKey: "repoPaths_v2"), ["/tmp/second", "/tmp/third", "/tmp/first"])
        XCTAssertEqual(
            store.defaults.stringArray(forKey: "tabOrder"),
            ["stashes", "worktrees", "pullRequests", "branches"]
        )
    }

    private func defaults() -> (domain: String, defaults: UserDefaults) {
        let domain = "com.example.GitBarTests.\(UUID().uuidString)"
        return (domain, UserDefaults(suiteName: domain)!)
    }

    private func removeDomain(for store: (domain: String, defaults: UserDefaults)) {
        store.defaults.removePersistentDomain(forName: store.domain)
    }
}
