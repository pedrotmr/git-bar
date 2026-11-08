nonisolated enum AppTab: String, CaseIterable, Identifiable, Sendable {
    private struct Definition {
        let title: String
        let settingsLabel: String
        let visibilityDefaultsKey: String
        let isVisibleByDefault: Bool
    }

    case branches
    case worktrees
    case stashes
    case pullRequests

    static let defaultOrder: [AppTab] = [.branches, .stashes, .worktrees, .pullRequests]

    var id: String { rawValue }

    private var definition: Definition {
        switch self {
        case .branches:
            Definition(
                title: "Branches",
                settingsLabel: "branches",
                visibilityDefaultsKey: "showBranchesTab",
                isVisibleByDefault: true
            )
        case .worktrees:
            Definition(
                title: "Worktrees",
                settingsLabel: "worktrees",
                visibilityDefaultsKey: "showWorktreeTab",
                isVisibleByDefault: true
            )
        case .stashes:
            Definition(
                title: "Stashes",
                settingsLabel: "stashes",
                visibilityDefaultsKey: "showStashTab",
                isVisibleByDefault: true
            )
        case .pullRequests:
            Definition(
                title: "PRs",
                settingsLabel: "pull requests",
                visibilityDefaultsKey: "showPRTab",
                isVisibleByDefault: true
            )
        }
    }

    var title: String { definition.title }
    var settingsLabel: String { definition.settingsLabel }
    var visibilityDefaultsKey: String { definition.visibilityDefaultsKey }
    var isVisibleByDefault: Bool { definition.isVisibleByDefault }
}
