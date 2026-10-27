import AppKit
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let controller: SPUStandardUpdaterController
    private let managedByHomebrew: Bool

    init() {
        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.GitBar.app"
        let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(
            bundleIdentifier: bundleIdentifier,
            installedVersion: installedVersion,
            bundleURL: Bundle.main.bundleURL
        )
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    func checkForUpdates() {
        if managedByHomebrew {
            let alert = NSAlert()
            alert.messageText = "Updates are managed by Homebrew"
        alert.informativeText = "Run `brew update`, then `brew upgrade --cask --greedy-auto-updates pedrotmr/git-bar/pedrotmr-git-bar` to update GitBar."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        controller.checkForUpdates(nil)
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
