import Foundation

nonisolated struct RepositoryLocation: Sendable {
    let path: String

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var shortenedPath: String {
        path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }
}
