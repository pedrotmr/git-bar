import AppKit
import Foundation

@MainActor
enum WorktreeApplicationLauncher {
    static func openInTerminal(_ directory: URL, terminal: SupportedTerminal) {
        guard let appURL = AppDetector.appURL(bundleIdentifier: terminal.rawValue) else {
            NSWorkspace.shared.open(directory)
            return
        }

        guard terminal == .cmux else {
            NSWorkspace.shared.open(
                [directory],
                withApplicationAt: appURL,
                configuration: .init(),
                completionHandler: nil
            )
            return
        }

        let cli = appURL.appendingPathComponent("Contents/Resources/bin/cmux")
        let process = Process()
        process.executableURL = cli
        process.arguments = [
            "new-workspace",
            "--command",
            "cd '\(shellQuoted(directory.path))' && exec $SHELL",
        ]
        do {
            try process.run()
        } catch {
            NSWorkspace.shared.open(directory)
        }
    }

    static func openInEditor(_ directory: URL, editor: SupportedEditor) {
        guard let appURL = AppDetector.appURL(bundleIdentifier: editor.rawValue) else {
            NSWorkspace.shared.open(directory)
            return
        }
        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: appURL,
            configuration: .init(),
            completionHandler: nil
        )
    }

    private static func shellQuoted(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}
