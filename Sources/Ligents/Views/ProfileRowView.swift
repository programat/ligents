import SwiftUI

struct ProfileRowView: View {
    let profile: ProviderProfile
    let usageWindows: [UsageWindow]
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

                    Text(providerSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(status: profile.status)

                    if !usageWindows.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Label(isExpanded ? "Hide" : "Details", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
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
        .animation(.easeOut(duration: 0.18), value: isExpanded)
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
        } else {
            VStack(spacing: 10) {
                profileSummaryStrip

                if isExpanded {
                    ForEach(usageWindows) { window in
                        UsageWindowView(window: window)
                    }

                    expandedMeta
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
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

    private var profileSummaryStrip: some View {
        HStack(spacing: 10) {
            summaryMetric(
                title: "5h",
                value: metricValue(for: .session)
            )

            Rectangle()
                .fill(DashboardPalette.hairline)
                .frame(width: 1, height: 14)

            summaryMetric(
                title: "Week",
                value: metricValue(for: .weekly)
            )

            Spacer(minLength: 0)
        }
        .font(.caption.monospacedDigit())
        .padding(.vertical, 2)
    }

    private var expandedMeta: some View {
        HStack(spacing: 16) {
            Label(syncSummary, systemImage: "clock")
            Label(profile.connectionType.displayName, systemImage: "link")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
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
        guard let window = usageWindows.first(where: { $0.kind == kind }) else {
            return "n/a"
        }

        let remaining = window.remainingPercent ?? window.usedPercent.map { 100 - $0 }
        guard let remaining else {
            return "n/a"
        }

        return "\(Int(remaining.rounded()))% left"
    }
}
