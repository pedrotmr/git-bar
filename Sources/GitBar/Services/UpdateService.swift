import AppKit
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateService {
    private let userDriverDelegate: UpdaterUserDriverDelegate
    private let controller: SPUStandardUpdaterController

    init() {
        let userDriverDelegate = UpdaterUserDriverDelegate()
        self.userDriverDelegate = userDriverDelegate
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.GitBar.app"
        let managedByHomebrew = HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier)
        controller = SPUStandardUpdaterController(
            startingUpdater: !managedByHomebrew,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    func checkForUpdates() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.GitBar.app"
        if HomebrewInstallDetector.isManagedByHomebrew(bundleIdentifier: bundleIdentifier) {
            let alert = NSAlert()
            alert.messageText = "Updates are managed by Homebrew"
            alert.informativeText = "Run `brew update && brew upgrade` to update GitBar."
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
