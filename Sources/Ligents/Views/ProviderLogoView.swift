import AppKit
import SwiftUI

struct ProviderLogoView: View {
    let provider: Provider
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = image {
                if provider.usesTemplateLogo {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Image(systemName: provider.systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(max(3, size * 0.18))
        .frame(width: size, height: size)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel(provider.displayName)
    }

    private var image: NSImage? {
        guard let url = Bundle.module.url(
            forResource: provider.logoResourceName,
            withExtension: "svg"
        ) else {
            return nil
        }

        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        if provider.usesTemplateLogo {
            image.isTemplate = true
        }

        return image
    }
}
