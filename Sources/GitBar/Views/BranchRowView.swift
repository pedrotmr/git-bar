import SwiftUI

struct BranchRowView: View {
    private enum DeletionAction {
        case regular
        case localAndRemote
        case force

        func title(for branchName: String) -> String {
            switch self {
            case .regular: "Delete branch \"\(branchName)\"?"
            case .localAndRemote: "Delete \"\(branchName)\" locally and from remote?"
            case .force: "Force delete branch \"\(branchName)\"?"
            }
        }

        var buttonTitle: String {
            switch self {
            case .regular: "Delete"
            case .localAndRemote: "Delete Local & Remote"
            case .force: "Force Delete"
            }
        }

        var message: String {
            switch self {
            case .regular:
                "This cannot be undone."
            case .localAndRemote:
                "The local branch and its remote counterpart on origin will both be deleted. This cannot be undone."
            case .force:
                "The branch will be permanently deleted, even if it has unmerged changes. This cannot be undone."
            }
        }
    }

    let branch: Branch
    @Environment(GitService.self) private var gitService
    @Environment(SettingsService.self) private var settingsService
    @State private var isHovered = false
    @State private var pendingDeletion: DeletionAction?
    @State private var showUnmergedChangesDialog = false
    @State private var showDeleteBothConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(branch.isCurrent ? Color.green : Color.secondary.opacity(0.25))
                .frame(width: 7, height: 7)

            HStack(spacing: 8) {
                Text(branch.name)
                    .font(.system(size: 13, weight: branch.isCurrent ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if branch.ahead > 0 {
                    trackingStatus(branch.ahead, symbol: "arrow.up", direction: "ahead of")
                }
                if branch.behind > 0 {
                    trackingStatus(branch.behind, symbol: "arrow.down", direction: "behind")
                }
            }

            Spacer()

            HStack(spacing: 2) {
                if branch.isCurrent, let upstream = branch.upstream {
                    HoverIconButton(systemImage: "arrow.down.circle", tooltip: "Fetch and pull from \(upstream)") {
                        Task { await gitService.pullCurrentBranch() }
                    }
                    .opacity(isHovered ? 1 : 0)
                } else if !branch.isCurrent {
                    HoverIconButton(systemImage: "arrow.trianglehead.swap", tooltip: "Switch to branch") {
                        Task { await gitService.switchBranch(branch.name) }
                    }
                    .opacity(isHovered ? 1 : 0)

                    HoverIconButton(systemImage: "trash", tooltip: "Delete branch") {
                    requestDeletion(.regular)
                    }
                    .opacity(isHovered ? 1 : 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { isHovered = h } }
        .padding(.horizontal, 6)
        .contextMenu {
            if !branch.isCurrent {
                Button("Switch to Branch") {
                    Task { await gitService.switchBranch(branch.name) }
                }
            }
            Divider()
                Button("Delete", role: .destructive) {
                    requestDeletion(.regular)
            }
            .disabled(branch.isCurrent)
            Button("Delete Local & Remote", role: .destructive) {
                    requestDeletion(.localAndRemote)
            }
            .disabled(branch.isCurrent)
            Button("Force Delete", role: .destructive) {
                    requestDeletion(.force)
            }
            .disabled(branch.isCurrent)
        }
        .confirmationDialog(
            pendingDeletion?.title(for: branch.name) ?? "",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeletion {
                Button(pendingDeletion.buttonTitle, role: .destructive) {
                    self.pendingDeletion = nil
                    Task { await performDeletion(pendingDeletion) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let pendingDeletion {
                Text(pendingDeletion.message)
            }
        }
        .confirmationDialog(
            "Branch has unmerged changes",
            isPresented: $showUnmergedChangesDialog,
            titleVisibility: .visible
        ) {
            Button("Force Delete", role: .destructive) {
                gitService.errorMessage = nil
                Task { await gitService.deleteBranch(branch.name, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The branch \"\(branch.name)\" contains commits that haven't been merged. Force delete?")
        }
    }

    private func trackingStatus(_ count: Int, symbol: String, direction: String) -> some View {
        Label("\(count)", systemImage: symbol)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .help("\(count) commit\(count == 1 ? "" : "s") \(direction) \(branch.upstream ?? "upstream")")
    }

    private func requestDeletion(_ action: DeletionAction) {
        Task {
            if await needsDeleteConfirmation() {
                pendingDeletion = action
            } else {
                await performDeletion(action)
            }
        }
    }

    private func needsDeleteConfirmation() async -> Bool {
        if settingsService.confirmBranchDeletion { return true }
        return await gitService.branchNeedsDeleteConfirmation(branch.name)
    }

    private func performDeletion(_ action: DeletionAction) async {
        switch action {
        case .regular:
            await gitService.deleteBranch(branch.name)
            showUnmergedDialogIfNeeded()
        case .localAndRemote:
            await gitService.deleteLocalAndRemoteBranch(branch.name)
        case .force:
            await gitService.deleteBranch(branch.name, force: true)
        }
    }

    private func showUnmergedDialogIfNeeded() {
        if gitService.errorMessage != nil {
            showUnmergedChangesDialog = true
        }
    }
}

struct HoverIconButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .customTooltip(tooltip)
    }
}
