import Foundation

nonisolated struct Stash: Identifiable, Hashable, Sendable {
    var id: String { ref }
    let ref: String
    let message: String
}
