import Foundation

struct Branch: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isCurrent: Bool
    let upstream: String?
    let ahead: Int
    let behind: Int

    init(name: String, isCurrent: Bool, upstream: String? = nil, ahead: Int = 0, behind: Int = 0) {
        self.name = name
        self.isCurrent = isCurrent
        self.upstream = upstream
        self.ahead = ahead
        self.behind = behind
    }
}
