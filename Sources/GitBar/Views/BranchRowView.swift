import SwiftUI

struct BranchRowView: View {
    let branch: Branch
    @Environment(GitService.self) private var gitService
    @Environment(SettingsService.self) private var settingsService
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    @State private var showForceDeleteConfirm = false
    @State private var showUnmergedChangesDialog = false
    @State private var showDeleteBothConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
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

            // Keep row actions together and reveal them on hover.
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
                        requestDelete()
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
                requestDelete()
            }
            .disabled(branch.isCurrent)
            Button("Delete Local & Remote", role: .destructive) {
                requestDeleteBoth()
            }
            .disabled(branch.isCurrent)
            Button("Force Delete", role: .destructive) {
                requestForceDelete()
            }
            .disabled(branch.isCurrent)
        }
        .confirmationDialog(
            "Delete branch \"\(branch.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await gitService.deleteBranch(branch.name)
                    showUnmergedDialogIfNeeded()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete \"\(branch.name)\" locally and from remote?",
            isPresented: $showDeleteBothConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Local & Remote", role: .destructive) {
                Task { await gitService.deleteLocalAndRemoteBranch(branch.name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The local branch and its remote counterpart on origin will both be deleted. This cannot be undone.")
        }
        .confirmationDialog(
            "Force delete branch \"\(branch.name)\"?",
            isPresented: $showForceDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Force Delete", role: .destructive) {
                Task { await gitService.deleteBranch(branch.name, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The branch will be permanently deleted, even if it has unmerged changes. This cannot be undone.")
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

    private func requestDelete() {
        Task {
            if await needsDeleteConfirmation() {
                showDeleteConfirm = true
            } else {
                await deleteBranch()
            }
        }
    }

    private func requestForceDelete() {
        Task {
            if await needsDeleteConfirmation() {
                showForceDeleteConfirm = true
            } else {
                await gitService.deleteBranch(branch.name, force: true)
            }
        }
    }

    private func requestDeleteBoth() {
        Task {
            if await needsDeleteConfirmation() {
                showDeleteBothConfirm = true
            } else {
                await gitService.deleteLocalAndRemoteBranch(branch.name)
            }
        }
    }

    private func needsDeleteConfirmation() async -> Bool {
        if settingsService.confirmBranchDeletion { return true }
        return await gitService.branchHasUncommittedChanges(branch.name)
    }

    private func deleteBranch() async {
        await gitService.deleteBranch(branch.name)
        showUnmergedDialogIfNeeded()
    }

    private func showUnmergedDialogIfNeeded() {
        if gitService.errorMessage != nil {
            showUnmergedChangesDialog = true
        }
    }
}

// MARK: - Shared hover components

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
