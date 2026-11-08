import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(GitService.self) private var gitService
    @Environment(SettingsService.self) private var settingsService
    @State private var selectedTab: AppTab = .branches
    @State private var showRepoList = false
    @State private var showSettings = false
    @State private var draggingTab: AppTab?
    @State private var dropTargetTab: AppTab?

    var body: some View {
        ZStack {
            mainView
                .offset(x: (showRepoList || showSettings) ? -440 : 0)

            RepoListView(isShowing: $showRepoList, onShowSettings: {
                withAnimation {
                    showRepoList = false
                    showSettings = true
                }
            })
            .offset(x: showRepoList ? 0 : 440)

            SettingsView(isShowing: $showSettings)
                .offset(x: showSettings ? 0 : 440)
        }
        .animation(.spring(duration: 0.28, bounce: 0.05), value: showRepoList)
        .animation(.spring(duration: 0.28, bounce: 0.05), value: showSettings)
        .frame(width: 440, height: 500)
        .onChange(of: settingsService.selectedRepoPath) { _, path in
            gitService.selectRepository(path)
            guard path != nil else { return }
            if gitService.isPopoverVisible {
                Task { await gitService.refreshAfterRepoSelection() }
            }
        }
        .onChange(of: settingsService.tabVisibility) { _, _ in
            if !settingsService.isTabVisible(selectedTab) { selectFirstVisibleTab() }
        }
        .onChange(of: settingsService.autoFetchEnabled) { _, enabled in
            gitService.autoFetchEnabled = enabled
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            repoHeader
            Divider().opacity(0.5)

            if gitService.repoPath.isEmpty {
                emptyState
            } else {
                if let error = gitService.errorMessage { errorBanner(error) }
                if hasVisibleTabs {
                    tabBar
                    Divider().opacity(0.5)
                    selectedTabView
                } else {
                    AllTabsHiddenView()
                }
            }

            Divider().opacity(0.5)
            BottomBar(onSettings: { withAnimation { showSettings = true } })
        }
        .frame(width: 440, height: 500)
    }

    @ViewBuilder private var selectedTabView: some View {
        switch selectedTab {
        case .branches: BranchesView()
        case .worktrees: WorktreesView()
        case .stashes: StashesView()
        case .pullRequests: PullRequestsView()
        }
    }

    private var repoHeader: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(gitService.repoPath.isEmpty ? Color.secondary.opacity(0.15) : Color.green.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(gitService.repoPath.isEmpty ? Color.secondary : Color.green)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(repoName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !gitService.repoPath.isEmpty {
                        Text(shortPath)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Click to select a repository")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { showRepoList = true } }

            IconButton(systemImage: "plus", tooltip: "Add repository", action: addRepo)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 58)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(settingsService.tabOrder) { tab in
                if settingsService.isTabVisible(tab) {
                    TabButton(title: tab.title, count: tabCount(tab), tab: tab, selected: selectedTab) {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                    }
                    .opacity(draggingTab == tab ? 0.4 : 1)
                    .background(dropTargetTab == tab && draggingTab != tab ? Color.accentColor.opacity(0.1) : .clear)
                    .onDrag {
                        draggingTab = tab
                        return NSItemProvider(object: tab.rawValue as NSString)
                    }
                    .onDrop(
                        of: [.plainText],
                        isTargeted: Binding(
                            get: { dropTargetTab == tab },
                            set: { isTarget in
                                if isTarget { dropTargetTab = tab }
                                else if dropTargetTab == tab { dropTargetTab = nil }
                            }
                        )
                    ) { providers in
                        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                            guard let rawValue = item as? String else { return }
                            DispatchQueue.main.async {
                                if let source = AppTab(rawValue: rawValue) {
                                    settingsService.moveTab(from: source, onto: tab)
                                }
                                draggingTab = nil
                                dropTargetTab = nil
                            }
                        }
                        return true
                    }
                }
            }
        }
        .frame(height: 38)
    }

    private var hasVisibleTabs: Bool {
        settingsService.tabOrder.contains(where: settingsService.isTabVisible)
    }

    private func selectFirstVisibleTab() {
        if let first = settingsService.tabOrder.first(where: settingsService.isTabVisible) {
            selectedTab = first
        }
    }

    private func tabCount(_ tab: AppTab) -> Int {
        switch tab {
        case .branches: gitService.branches.count
        case .worktrees: gitService.worktrees.count
        case .stashes: gitService.stashes.count
        case .pullRequests: gitService.pullRequests.count
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("No repository selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Text("Click the header to add or select\na git repository")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button {
                gitService.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    private var repoName: String {
        guard !gitService.repoPath.isEmpty else { return "No Repository" }
        return RepositoryLocation(path: gitService.repoPath).name
    }

    private var shortPath: String {
        RepositoryLocation(path: gitService.repoPath).shortenedPath
    }

    private func addRepo() {
        guard let path = openRepoPicker() else { return }
        Task {
            if await gitService.isGitRepo(path) {
                settingsService.addRepo(path)
            }
        }
    }
}
