import SwiftUI

struct ProfileRowView: View {
    let profile: ProviderProfile
    let usageWindows: [UsageWindow]
    var isPinned = false
    var onTogglePinned: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ProviderLogoView(provider: profile.provider, size: 20)
                    .frame(width: 20, height: 20)
                    .padding(8)
                    .background(
                        DashboardPalette.elevatedFill,
                        in: RoundedRectangle(cornerRadius: DashboardPalette.iconCornerRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DashboardPalette.iconCornerRadius, style: .continuous)
                            .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.email ?? profile.displayName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        CopyEmailButton(email: profile.email)
                            .opacity(isHovering ? 1 : 0)
                            .allowsHitTesting(isHovering)
                    }

                    collapsedSummaryLine
                }

                Spacer(minLength: 8)

                trailingControls
            }

            content

            if let lastError = profile.lastError, isExpanded || usageWindows.isEmpty {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if usageWindows.isEmpty {
            HStack(spacing: 10) {
                Text("No usage observed yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(profile.connectionType.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else if isExpanded {
            VStack(spacing: 10) {
                ForEach(usageWindows) { window in
                    UsageWindowView(window: window, isMuted: profile.status == .disabled)
                }

                expandedMeta
            }
            .transition(expandedContentTransition)
        }
    }

    private var providerSummary: String {
        if let plan = profile.planType, !plan.isEmpty {
            return "\(profile.provider.displayName)  •  \(plan)"
        }

        return profile.provider.displayName
    }

    private var syncSummary: String {
        let exact = DisplayFormatters.syncTimestampLabel(for: profile.lastSuccessfulSyncAt)
        let relative = DisplayFormatters.syncAgeLabel(for: profile.lastSuccessfulSyncAt)
        return "\(exact)  •  \(relative)"
    }

    private var collapsedSummaryLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(providerSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !usageWindows.isEmpty {
                HStack(spacing: 8) {
                    summaryMetric(
                        title: "5h",
                        value: metricValue(for: .session)
                    )

                    summaryMetric(
                        title: "Week",
                        value: metricValue(for: .weekly)
                    )
                }
                .font(.caption.monospacedDigit())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .lineLimit(1)
    }

    private var trailingControls: some View {
        HStack(alignment: .center, spacing: 8) {
            if onTogglePinned != nil {
                Button(action: togglePinned) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(pinForeground)
                        .background(
                            pinBackground,
                            in: RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DashboardPalette.controlCornerRadius, style: .continuous)
                                .strokeBorder(pinBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin subscription" : "Pin subscription")
                .help(isPinned ? "Unpin subscription" : "Pin subscription")
                .opacity(isPinned || isHovering ? 1 : 0.58)
            }

            StatusPill(status: profile.status)

            if !usageWindows.isEmpty {
                Button {
                    withAnimation(expansionAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: reduceMotion ? (isExpanded ? "chevron.down" : "chevron.right") : "chevron.right")
                            .rotationEffect(.degrees(!reduceMotion && isExpanded ? 90 : 0))

                        Text("Details")
                    }
                    .lineLimit(1)
                }
                .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(DashboardPalette.surfaceFill, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var expansionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.22)
    }

    private var expandedContentTransition: AnyTransition {
        .opacity
    }

    private var expandedMeta: some View {
        HStack(spacing: 16) {
            Label(syncSummary, systemImage: "clock")
            Label(profile.connectionType.displayName, systemImage: "link")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var pinBackground: Color {
        isPinned ? Color.accentColor.opacity(0.12) : DashboardPalette.surfaceFill
    }

    private var pinBorder: Color {
        isPinned ? Color.accentColor.opacity(0.20) : DashboardPalette.hairline
    }

    private var pinForeground: Color {
        isPinned ? Color.accentColor : Color.secondary
    }

    private func togglePinned() {
        onTogglePinned?()
    }

    private func summaryMetric(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func metricValue(for kind: UsageWindowKind) -> String {
        let remaining = ProfileInsights.remainingPercent(in: usageWindows, kind: kind)
        guard let remaining else {
            return "n/a"
        }

        return "\(Int(remaining.rounded()))% left"
    }
}
