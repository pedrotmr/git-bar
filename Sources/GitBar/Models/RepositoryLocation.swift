import Foundation

nonisolated struct RepositoryLocation: Sendable {
    let path: String

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var shortenedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        let homePrefix = home.hasSuffix("/") ? home : home + "/"
        guard path.hasPrefix(homePrefix) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
