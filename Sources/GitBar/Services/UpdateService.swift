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
            let updateCommand = "brew update && brew upgrade --cask --greedy-auto-updates pedrotmr/git-bar/pedrotmr-git-bar"
            let alert = NSAlert()
            alert.messageText = "Updates are managed by Homebrew"
            alert.informativeText = "To update GitBar, copy and run this command in Terminal:\n\n\(updateCommand)"
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(updateCommand, forType: .string)
            }
            return
        }
        controller.checkForUpdates(nil)
    }
}

@MainActor
private final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
