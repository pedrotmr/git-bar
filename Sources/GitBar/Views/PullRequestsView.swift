import SwiftUI

struct PullRequestsView: View {
    @Environment(GitService.self) private var gitService

    private var groupedPRs: [PRCategory: [PullRequest]] {
        Dictionary(grouping: gitService.pullRequests, by: \.category)
    }
    private var created: [PullRequest] { groupedPRs[.created] ?? [] }
    private var assigned: [PullRequest] { groupedPRs[.assigned] ?? [] }
    private var reviewRequested: [PullRequest] { groupedPRs[.reviewRequested] ?? [] }

    var body: some View {
        CollectionStateView(
            isLoading: gitService.isLoading,
            isEmpty: gitService.pullRequests.isEmpty,
            emptySymbol: "arrow.triangle.pull",
            emptyMessage: "No pull requests found"
        ) {
            LazyVStack(spacing: 1, pinnedViews: []) {
                if !created.isEmpty {
                    sectionHeader("Created")
                    ForEach(created) { pr in
                        PullRequestRowView(pr: pr)
                    }
                }
                if !assigned.isEmpty {
                    if !created.isEmpty { sectionDivider }
                    sectionHeader("Assigned")
                    ForEach(assigned) { pr in
                        PullRequestRowView(pr: pr)
                    }
                }
                if !reviewRequested.isEmpty {
                    if !created.isEmpty || !assigned.isEmpty { sectionDivider }
                    sectionHeader("Requested for Review")
                    ForEach(reviewRequested) { pr in
                        PullRequestRowView(pr: pr)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .opacity(0.6)
    }
}
