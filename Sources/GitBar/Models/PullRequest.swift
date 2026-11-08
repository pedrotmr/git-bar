import Foundation

nonisolated enum PRCategory: Sendable { case created, assigned, reviewRequested }

nonisolated struct PullRequest: Identifiable, Hashable, Sendable {
    var id: Int { number }
    let number: Int
    let title: String
    let headRefName: String
    let url: String
    let category: PRCategory
}
