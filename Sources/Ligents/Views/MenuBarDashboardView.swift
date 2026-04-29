import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var frozenDashboardState: DashboardViewState?

    private var dashboardState: DashboardViewState {
        frozenDashboardState ?? liveDashboardState
    }

    private var liveDashboardState: DashboardViewState {
        let usageWindowsByProfileID = ProfileInsights.windowsByProfileID(in: model.usageWindows)
        let snapshots = ProfileInsights.snapshots(
            profiles: model.profiles,
            usageWindowsByProfileID: usageWindowsByProfileID
        )
        let recommended = ProfileInsights.recommended(from: snapshots)

        return DashboardViewState(
            snapshots: snapshots,
            recommended: recommended,
            profiles: sortedProfiles(using: snapshots).map { profile in
                DashboardProfileRowState(
                    profile: profile,
                    usageWindows: usageWindowsByProfileID[profile.id] ?? [],
                    isPinned: model.isProfilePinned(profile)
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if model.profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add a provider profile in Settings.")
                )
                .frame(width: 380, height: 180)
            } else {
                DashboardResizableScrollView(onResizePhaseChanged: handleResizePhaseChanged) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        DashboardInsightView(
                            snapshots: dashboardState.snapshots,
                            recommended: dashboardState.recommended
                        )
                            .dashboardSurface()

                        DashboardSectionHeaderView(
                            title: "Profiles",
                            detail: "Sorted by availability"
                        )

                        VStack(spacing: 10) {
                            ForEach(dashboardState.profiles) { row in
                                ProfileRowView(
                                    profile: row.profile,
                                    usageWindows: row.usageWindows,
                                    isPinned: row.isPinned,
                                    onTogglePinned: {
                                        model.toggleProfilePinned(row.profile)
                                    }
                                )
                                .dashboardSurface(isError: row.isError)
                            }
                        }
                    }
                } footer: {
                    footer
                }
            }
        }
        .padding(DashboardPalette.surfacePadding)
        .frame(width: 500)
        .background(
            DashboardPalette.popoverBackground,
            in: RoundedRectangle(cornerRadius: DashboardPalette.popoverCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DashboardPalette.popoverCornerRadius, style: .continuous)
                .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: DashboardPalette.iconCornerRadius, style: .continuous)
                    .fill(DashboardPalette.surfaceFill)

                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ligents")
                    .font(.title3.weight(.semibold))

                Text(subscriptionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer()

            Text(lastRefreshSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 170, alignment: .trailing)

            Button(action: refreshProfiles) {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
                    .frame(width: 30, height: 30)
                    .background(
                        DashboardPalette.surfaceFill,
                        in: RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
                            .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help("Refresh all profiles")
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            Button(action: openPings) {
                Label("Readiness", systemImage: "wave.3.right.circle")
            }
            .buttonStyle(DashboardFooterButtonStyle(tone: .primary))

            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(DashboardFooterButtonStyle(tone: .primary))

            Spacer()

            Button(role: .destructive, action: quitApp) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(DashboardFooterButtonStyle(tone: .secondary))
        }
        .padding(.horizontal, 12)
        .frame(height: DashboardPalette.footerHeight)
        .frame(maxWidth: .infinity)
    }

    private var subscriptionSummary: String {
        let total = model.profiles.count
        let active = model.profiles.filter { $0.status == .active }.count

        if total == 0 {
            return "No subscriptions"
        }

        let noun = total == 1 ? "subscription" : "subscriptions"
        return "\(total) \(noun) • \(active) active"
    }

    private var lastRefreshSummary: String {
        let latest = model.profiles
            .compactMap(\.lastSuccessfulSyncAt)
            .max()

        guard let latest else {
            return "Never refreshed"
        }

        return "Refreshed \(DisplayFormatters.syncTimestampLabel(for: latest))"
    }

    private func sortedProfiles(using snapshots: [ProfileUsageSnapshot]) -> [ProviderProfile] {
        let ranking = Dictionary(
            uniqueKeysWithValues: snapshots.enumerated().map { index, snapshot in
                (snapshot.profile.id, snapshot.recommendationScore - Double(index) * 0.001)
            }
        )

        return model.profiles.sorted { lhs, rhs in
            let leftPinned = model.isProfilePinned(lhs)
            let rightPinned = model.isProfilePinned(rhs)
            if leftPinned != rightPinned {
                return leftPinned
            }

            let leftScore = ranking[lhs.id] ?? -1000
            let rightScore = ranking[rhs.id] ?? -1000

            if leftScore == rightScore {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            return leftScore > rightScore
        }
    }

    private func handleResizePhaseChanged(_ isResizing: Bool) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            frozenDashboardState = isResizing ? liveDashboardState : nil
        }
    }

    private func refreshProfiles() {
        model.refreshAll()
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    private func openPings() {
        UserDefaults.standard.set(SettingsSection.pings.rawValue, forKey: "settings.selection")
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

private struct DashboardViewState {
    var snapshots: [ProfileUsageSnapshot]
    var recommended: ProfileUsageSnapshot?
    var profiles: [DashboardProfileRowState]
}

private struct DashboardProfileRowState: Identifiable {
    var profile: ProviderProfile
    var usageWindows: [UsageWindow]
    var isPinned: Bool

    var id: UUID {
        profile.id
    }

    var isError: Bool {
        profile.status == .error
    }
}

private struct DashboardFooterButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
    }

    let tone: Tone
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous))
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
                    .strokeBorder(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch tone {
        case .primary:
            return .primary
        case .secondary:
            return isPressed ? .primary : .secondary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch tone {
        case .primary:
            return isPressed ? DashboardPalette.elevatedFill : DashboardPalette.surfaceFill
        case .secondary:
            return isPressed ? DashboardPalette.surfaceFill : Color.clear
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch tone {
        case .primary:
            return DashboardPalette.hairline
        case .secondary:
            return isPressed ? DashboardPalette.hairline : Color.clear
        }
    }
}

private struct DashboardResizableScrollView<Content: View, Footer: View>: View {
    @AppStorage("dashboard.scrollHeight") private var persistedScrollHeight = Double(DashboardPalette.scrollMinimumHeight)
    @State private var dragStartHeight: Double?
    @State private var liveScrollHeight: Double?
    var onResizePhaseChanged: (Bool) -> Void = { _ in }
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
            }
            .padding(.vertical, 3)
            .frame(height: CGFloat(currentHeight))

            bottomBar
        }
        .frame(width: DashboardPalette.contentWidth)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            footer
            resizeHandle
        }
        .background(.thinMaterial)
    }

    private var resizeHandle: some View {
        ZStack {
            Color.clear

            Capsule()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 42, height: 3)
        }
        .frame(height: DashboardPalette.resizeHandleHeight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(resizeGesture)
        .help("Drag to resize")
        .accessibilityLabel("Resize dashboard")
    }

    private var currentHeight: Double {
        liveScrollHeight ?? clamp(persistedScrollHeight)
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let startHeight = dragStartHeight ?? clamp(persistedScrollHeight)
                if dragStartHeight == nil {
                    dragStartHeight = startHeight
                    onResizePhaseChanged(true)
                }

                updateLiveHeight(startHeight + value.translation.height.rounded())
            }
            .onEnded { value in
                let startHeight = dragStartHeight ?? clamp(persistedScrollHeight)
                commitHeight(startHeight + value.translation.height.rounded())
            }
    }

    private func updateLiveHeight(_ height: Double) {
        let nextHeight = clamp(height)
        guard liveScrollHeight != nextHeight else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            liveScrollHeight = nextHeight
        }
    }

    private func commitHeight(_ height: Double) {
        let nextHeight = clamp(height)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if persistedScrollHeight != nextHeight {
                persistedScrollHeight = nextHeight
            }
            liveScrollHeight = nil
            dragStartHeight = nil
        }
        onResizePhaseChanged(false)
    }

    private func clamp(_ height: Double) -> Double {
        min(
            max(height, Double(DashboardPalette.scrollMinimumHeight)),
            Double(DashboardPalette.scrollMaximumHeight)
        )
    }
}

private struct DashboardSurfaceModifier: ViewModifier {
    var isError = false

    func body(content: Content) -> some View {
        content
            .padding(DashboardPalette.surfacePadding)
            .background(
                isError ? DashboardPalette.errorSurfaceFill : DashboardPalette.surfaceFill,
                in: RoundedRectangle(cornerRadius: DashboardPalette.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DashboardPalette.cornerRadius, style: .continuous)
                    .strokeBorder(isError ? DashboardPalette.errorSurfaceBorder : DashboardPalette.hairline, lineWidth: 1)
            }
    }
}

private extension View {
    func dashboardSurface(isError: Bool = false) -> some View {
        modifier(DashboardSurfaceModifier(isError: isError))
    }
}
