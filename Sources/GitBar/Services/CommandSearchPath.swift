import Foundation

nonisolated enum CommandSearchPath {
    static func augmentedPath(existingPath: String?, homeDirectory: String) -> String {
        let preferred = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let existing = (existingPath ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (preferred + existing)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }

    static func executablePath(for command: String, path: String) -> String? {
        guard !command.isEmpty, !command.contains("/") else { return nil }
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent(command)
                .path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
