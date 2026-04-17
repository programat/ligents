import SwiftUI

struct SettingsHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))

                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                actions
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}
