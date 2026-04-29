import SwiftUI

enum DashboardPalette {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let softBackground = Color(nsColor: .underPageBackgroundColor)
    static let popoverBackground = windowBackground.opacity(0.98)
    static let surfaceFill = Color.primary.opacity(0.045)
    static let elevatedFill = Color.primary.opacity(0.06)
    static let sectionBackground = Color.primary.opacity(0.04)
    static let separator = Color.primary.opacity(0.055)
    static let hairline = Color.primary.opacity(0.075)
    static let errorSurfaceFill = Color.red.opacity(0.045)
    static let errorSurfaceBorder = Color.red.opacity(0.16)
    static let popoverCornerRadius: CGFloat = 18
    static let cornerRadius: CGFloat = 8
    static let controlCornerRadius: CGFloat = 8
    static let iconCornerRadius: CGFloat = 8
    static let surfacePadding: CGFloat = 12
    static let compactPadding: CGFloat = 10
    static let contentWidth: CGFloat = 472
    static let scrollMinimumHeight: CGFloat = 500
    static let scrollMaximumHeight: CGFloat = 820
    static let footerHeight: CGFloat = 44
    static let resizeHandleHeight: CGFloat = 12

    static func innerCornerRadius(for outerRadius: CGFloat = cornerRadius) -> CGFloat {
        min(controlCornerRadius, outerRadius)
    }
}
