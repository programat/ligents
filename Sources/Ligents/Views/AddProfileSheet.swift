import SwiftUI

struct AddProfileSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Profile")
                        .font(.title2.weight(.semibold))

                    Text("Create an isolated provider session and continue in the browser.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Provider")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ProviderChoiceButton(
                        provider: .codex,
                        isSelected: true,
                        isEnabled: true,
                        subtitle: "Supported now"
                    ) {}

                    ProviderChoiceButton(
                        provider: .claude,
                        isSelected: false,
                        isEnabled: false,
                        subtitle: "Unavailable now"
                    ) {}
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                InfoRow(
                    label: "Connection",
                    value: Provider.codex.defaultConnectionType.displayName
                )

                InfoRow(
                    label: "Profile Name",
                    value: "Assigned automatically after connect"
                )

                InfoRow(
                    label: "Email / Plan",
                    value: "Read from the connected Codex account"
                )
            }
            .padding(16)
            .background(BrandIdentity.accentSoft, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(BrandIdentity.accent.opacity(0.16), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(BrandIdentity.profileDescriptor)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(Provider.codex.supportSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Claude stays inactive here because consumer subscription auth and automatic usage tracking are still gated by provider policy and don't have a stable supported path for this app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create & Connect") {
                    guard let profile = model.createProfile(provider: .codex) else {
                        return
                    }
                    model.startBrowserAuth(for: profile)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

private struct ProviderChoiceButton: View {
    let provider: Provider
    let isSelected: Bool
    let isEnabled: Bool
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 6) {
                HStack(spacing: 8) {
                    ProviderLogoView(provider: provider, size: 18)

                    Text(provider.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderStyle, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(provider.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundStyle: Color {
        isSelected ? BrandIdentity.accentMuted : Color.secondary.opacity(0.08)
    }

    private var borderStyle: Color {
        isSelected ? BrandIdentity.accent : .secondary.opacity(0.18)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)

            Text(value)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}
