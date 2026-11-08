import SwiftUI

struct WorktreesView: View {
    @Environment(GitService.self) private var gitService

    var body: some View {
        CollectionStateView(
            isLoading: gitService.isLoading,
            isEmpty: gitService.worktrees.isEmpty,
            emptySymbol: "folder.badge.gearshape",
            emptyMessage: "No worktrees found"
        ) {
            LazyVStack(spacing: 1) {
                ForEach(gitService.worktrees) { worktree in
                    WorktreeRowView(worktree: worktree)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
