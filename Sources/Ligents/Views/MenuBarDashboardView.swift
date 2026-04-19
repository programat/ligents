import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var snapshots: [ProfileUsageSnapshot] {
        ProfileInsights.snapshots(
            profiles: model.profiles,
            usageWindows: model.usageWindows
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        DashboardInsightView(snapshots: snapshots)
                            .dashboardSurface()

                        DashboardSectionHeaderView(
                            title: "Profiles",
                            detail: "Sorted by availability"
                        )

                        VStack(spacing: 10) {
                            ForEach(sortedProfiles) { profile in
                                ProfileRowView(
                                    profile: profile,
                                    usageWindows: model.usageWindows(for: profile.id)
                                )
                                .dashboardSurface()
                            }
                        }
                    }
                }
                .padding(.vertical, 3)
                .frame(width: DashboardPalette.contentWidth)
                .frame(maxHeight: DashboardPalette.scrollMaxHeight)
                .safeAreaInset(edge: .bottom, spacing: 0) {
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
        .background(.thinMaterial)
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

    private var sortedProfiles: [ProviderProfile] {
        let ranking = Dictionary(
            uniqueKeysWithValues: snapshots.enumerated().map { index, snapshot in
                (snapshot.profile.id, snapshot.recommendationScore - Double(index) * 0.001)
            }
        )

        return model.profiles.sorted { lhs, rhs in
            let leftScore = ranking[lhs.id] ?? -1000
            let rightScore = ranking[rhs.id] ?? -1000

            if leftScore == rightScore {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            return leftScore > rightScore
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

private struct DashboardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DashboardPalette.surfacePadding)
            .background(
                DashboardPalette.surfaceFill,
                in: RoundedRectangle(cornerRadius: DashboardPalette.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DashboardPalette.cornerRadius, style: .continuous)
                    .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
            }
    }
}

private extension View {
    func dashboardSurface() -> some View {
        modifier(DashboardSurfaceModifier())
    }
}
