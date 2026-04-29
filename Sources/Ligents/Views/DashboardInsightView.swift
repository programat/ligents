import SwiftUI

struct DashboardInsightView: View {
    let snapshots: [ProfileUsageSnapshot]
    let recommended: ProfileUsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recommended")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let recommended {
                    HStack(spacing: 6) {
                        Text(recommended.profile.email ?? recommended.profile.displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        CopyEmailButton(email: recommended.profile.email)
                    }

                    Text(recommended.recommendationSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No connected profile yet")
                        .font(.headline)
                        .lineLimit(1)

                    Text("Add and connect a Codex profile to compare remaining session and weekly capacity.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(snapshots) { snapshot in
                        ProfileRingBadgeView(
                            snapshot: snapshot,
                            isRecommended: snapshot.id == recommended?.id
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }
}

private struct ProfileRingErrorGlow: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.20), lineWidth: 9)
                .frame(width: 48, height: 48)
                .blur(radius: 9)

            Circle()
                .stroke(Color.red.opacity(0.24), lineWidth: 5)
                .frame(width: 42, height: 42)
                .blur(radius: 5)
        }
        .frame(width: 62, height: 62)
        .allowsHitTesting(false)
    }
}

private struct ProfileRingBadgeView: View {
    let snapshot: ProfileUsageSnapshot
    let isRecommended: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(outerTrackColor, lineWidth: 5)

                Circle()
                    .trim(from: 0, to: sessionProgress)
                    .stroke(sessionColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .inset(by: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 4)

                Circle()
                    .inset(by: 6)
                    .trim(from: 0, to: weeklyProgress)
                    .stroke(weeklyColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                ProviderLogoView(provider: snapshot.profile.provider, size: 14)
            }
            .frame(width: 36, height: 36)
            .background {
                if hasProfileError {
                    ProfileRingErrorGlow()
                }
            }
            .overlay(alignment: .topTrailing) {
                if hasProfileError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red, DashboardPalette.windowBackground)
                        .background(Color.black.opacity(0.001), in: Circle())
                        .offset(x: 3, y: -3)
                } else if isRecommended {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .background(Color.black.opacity(0.001), in: Circle())
                        .offset(x: 3, y: -3)
                }
            }

            Text(snapshot.displayHandle)
                .font(.caption.monospacedDigit())
                .foregroundStyle(isRecommended ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.82)
                .frame(width: 58)
        }
        .padding(.vertical, 2)
        .help(helpText)
    }

    private var sessionProgress: Double {
        snapshot.sessionRemaining / 100
    }

    private var weeklyProgress: Double {
        snapshot.weeklyRemaining / 100
    }

    private var sessionColor: Color {
        if isMuted(window: snapshot.sessionWindow) {
            return .gray
        }

        return color(for: snapshot.sessionRemaining)
    }

    private var weeklyColor: Color {
        if isMuted(window: snapshot.weeklyWindow) {
            return .gray
        }

        return color(for: snapshot.weeklyRemaining)
    }

    private var hasProfileError: Bool {
        snapshot.profile.status == .error
    }

    private var outerTrackColor: Color {
        Color.primary.opacity(0.10)
    }

    private var helpText: String {
        if hasProfileError, let lastError = snapshot.profile.lastError {
            return "\(snapshot.recommendationSummary)\n\(lastError)"
        }

        return snapshot.recommendationSummary
    }

    private func isMuted(window: UsageWindow?) -> Bool {
        snapshot.profile.status == .disabled || window?.state == .stale || window == nil
    }

    private func color(for remaining: Double) -> Color {
        if remaining <= 5 {
            return .red
        }

        if remaining <= 20 {
            return .yellow
        }

        return .green
    }
}
