import SwiftUI

struct StashesView: View {
    @Environment(GitService.self) private var gitService

    var body: some View {
        CollectionStateView(
            isLoading: gitService.isLoading,
            isEmpty: gitService.stashes.isEmpty,
            emptySymbol: "archivebox",
            emptyMessage: "No stashes found"
        ) {
            LazyVStack(spacing: 1) {
                ForEach(gitService.stashes) { stash in
                    StashRowView(stash: stash)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
