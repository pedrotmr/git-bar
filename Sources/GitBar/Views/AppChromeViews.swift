import AppKit
import SwiftUI

struct AllTabsHiddenView: View {
    @State private var isAnimating = false

    private enum Constants {
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 32
        static let steamWispWidth: CGFloat = 3
        static let steamWispHeight: CGFloat = 8
        static let steamWispSpacing: CGFloat = 3
        static let steamWispOpacity: Double = 0.35
        static let steamOffsetX: CGFloat = -4
        static let steamOffsetY: CGFloat = -12
        static let animatedOffset: CGFloat = -6
        static let animationDuration: Double = 1.1
        static let animationStagger: Double = 0.3
        static let titleFontSize: CGFloat = 14
        static let subtitleFontSize: CGFloat = 12
    }

    var body: some View {
        VStack(spacing: Constants.spacing) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: Constants.iconSize, weight: .light))
                    .foregroundStyle(.secondary)
                VStack(spacing: Constants.steamWispSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.secondary.opacity(Constants.steamWispOpacity))
                            .frame(width: Constants.steamWispWidth, height: Constants.steamWispHeight)
                            .offset(y: isAnimating ? Constants.animatedOffset : 0)
                            .opacity(isAnimating ? 0 : 0.8)
                            .animation(
                                .easeInOut(duration: Constants.animationDuration)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * Constants.animationStagger),
                                value: isAnimating
                            )
                    }
                }
                .offset(x: Constants.steamOffsetX, y: Constants.steamOffsetY)
            }
            .onAppear { isAnimating = true }
            Text("Nothing brewing here.")
                .font(.system(size: Constants.titleFontSize, weight: .medium))
                .foregroundStyle(.primary)
            Text("Enable at least one tab in Settings to see something here.")
                .font(.system(size: Constants.subtitleFontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TabButton: View {
    let title: String
    let count: Int
    let tab: AppTab
    let selected: AppTab
    let action: () -> Void

    private var isSelected: Bool { tab == selected }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
                        )
                }
            }
            Spacer()
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .frame(maxWidth: .infinity)
    }
}

struct BackHeader<Trailing: View>: View {
    let title: String
    let action: () -> Void
    let trailing: Trailing
    @State private var isHovered = false

    init(
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(isHovered ? Color.primary.opacity(0.07) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            }
            .onTapGesture(perform: action)

            trailing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(height: 58)
    }
}

extension BackHeader where Trailing == EmptyView {
    init(title: String, action: @escaping () -> Void) {
        self.init(title: title, action: action, trailing: { EmptyView() })
    }
}

struct IconButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovered = false

    init(systemImage: String, tooltip: String = "", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tooltip = tooltip
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(isHovered ? Color.primary.opacity(0.07) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .customTooltip(tooltip)
    }
}

struct BottomBar: View {
    @Environment(GitService.self) private var gitService
    @Environment(UpdateService.self) private var updateService
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if gitService.isLoading {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 16, height: 16)
            }
            Spacer()
            IconButton(systemImage: "arrow.clockwise", tooltip: "Refresh") {
                Task { await gitService.refresh() }
            }
            .disabled(gitService.repoPath.isEmpty || gitService.isLoading)

            if let version = updateService.availableUpdateVersion {
                IconButton(systemImage: "arrow.down.circle.fill", tooltip: "Update to \(version)…") {
                    updateService.installAvailableUpdate()
                }
            }

            IconButton(systemImage: "gearshape", tooltip: "Settings", action: onSettings)
            IconButton(systemImage: "power", tooltip: "Quit") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
