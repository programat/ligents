import SwiftUI

enum SettingsLayout {
    static let contentMaxWidth: CGFloat = 820
    static let wideContentMaxWidth: CGFloat = 860
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 20
    static let stackSpacing: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let sectionPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = DashboardPalette.cornerRadius
    static let rowCornerRadius: CGFloat = DashboardPalette.controlCornerRadius
    static let labelWidth: CGFloat = 112

    static let cardFill = Color.primary.opacity(0.035)
    static let sectionFill = Color.primary.opacity(0.028)
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(SettingsLayout.cardPadding)
            .background(SettingsLayout.cardFill, in: RoundedRectangle(cornerRadius: SettingsLayout.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsLayout.cardCornerRadius)
                    .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
            }
    }
}
