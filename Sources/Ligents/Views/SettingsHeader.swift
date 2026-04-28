import SwiftUI

struct SettingsHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    actions
                }

                VStack(alignment: .trailing, spacing: 8) {
                    actions
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}
