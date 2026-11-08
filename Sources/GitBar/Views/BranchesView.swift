import SwiftUI

struct BranchesView: View {
    @Environment(GitService.self) private var gitService

    var body: some View {
        CollectionStateView(
            isLoading: gitService.isLoading,
            isEmpty: gitService.branches.isEmpty,
            emptySymbol: "arrow.triangle.branch",
            emptyMessage: "No branches found"
        ) {
            LazyVStack(spacing: 1) {
                ForEach(gitService.branches) { branch in
                    BranchRowView(branch: branch)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
