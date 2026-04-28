import SwiftUI

struct UsageWindowView: View {
    let window: UsageWindow
    var isMuted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(window.kind.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(window.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(remainingLabel)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isUsageMuted ? .secondary : .primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DashboardPalette.separator)

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(progressValue == 0 ? 0 : 8, geometry.size.width * progressValue))
                }
            }
            .frame(height: 8)
            .animation(.smooth(duration: 0.24), value: progressValue)

            HStack(spacing: 8) {
                Text(resetText)
                    .lineLimit(1)

                Spacer()

                Text(remainingText)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var progressValue: Double {
        if let remainingPercent = window.remainingPercent {
            return min(max(remainingPercent / 100, 0), 1)
        }

        guard let usedPercent = window.usedPercent else {
            return 0
        }

        return min(max((100 - usedPercent) / 100, 0), 1)
    }

    private var remainingLabel: String {
        guard let remainingPercent = resolvedRemainingPercent else {
            return "n/a"
        }

        return "\(Int(remainingPercent.rounded())) left"
    }

    private var tint: Color {
        if isUsageMuted {
            return .gray
        }

        guard let remainingPercent = resolvedRemainingPercent else {
            return .gray
        }

        if remainingPercent <= 5 {
            return .red
        }

        if remainingPercent <= 20 {
            return .yellow
        }

        return .green
    }

    private var isUsageMuted: Bool {
        isMuted || window.state == .stale
    }

    private var resetText: String {
        "Reset \(DisplayFormatters.resetLabel(for: window.resetsAt))"
    }

    private var usedText: String {
        guard let usedPercent = resolvedUsedPercent else {
            return "used n/a"
        }

        return "\(Int(usedPercent.rounded())) used"
    }

    private var remainingText: String {
        usedText
    }

    private var resolvedRemainingPercent: Double? {
        if let remainingPercent = window.remainingPercent {
            return remainingPercent
        }

        if let usedPercent = window.usedPercent {
            return max(0, 100 - usedPercent)
        }

        return nil
    }

    private var resolvedUsedPercent: Double? {
        if let usedPercent = window.usedPercent {
            return usedPercent
        }

        if let remainingPercent = window.remainingPercent {
            return max(0, 100 - remainingPercent)
        }

        return nil
    }
}
