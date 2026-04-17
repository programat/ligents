import SwiftUI

struct StatusPill: View {
    let status: ProfileStatus

    var body: some View {
        Label(status.displayName, systemImage: symbolName)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle, in: Capsule())
            .accessibilityLabel("Profile status \(status.displayName)")
    }

    private var foregroundStyle: Color {
        switch status {
        case .authenticating:
            .blue
        case .active, .syncing:
            .green
        case .authRequired, .degraded:
            .yellow
        case .error:
            .red
        case .disabled:
            .secondary
        }
    }

    private var backgroundStyle: Color {
        foregroundStyle.opacity(0.14)
    }

    private var symbolName: String {
        switch status {
        case .authenticating:
            "ellipsis.circle.fill"
        case .active:
            "checkmark.circle.fill"
        case .syncing:
            "arrow.triangle.2.circlepath.circle.fill"
        case .authRequired:
            "person.crop.circle.badge.exclamationmark"
        case .degraded:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        case .disabled:
            "pause.circle.fill"
        }
    }
}
