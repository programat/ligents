import SwiftUI

struct EditProfileSheet: View {
    @Bindable var model: AppModel
    let profile: ProviderProfile

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var email: String
    @State private var planType: String

    init(model: AppModel, profile: ProviderProfile) {
        self.model = model
        self.profile = profile
        _displayName = State(initialValue: profile.displayName)
        _email = State(initialValue: profile.email ?? "")
        _planType = State(initialValue: profile.planType ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Profile")
                        .font(.title2.weight(.semibold))

                    Text(profile.provider.supportSummary)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                LabeledContent("Provider") {
                    HStack(spacing: 8) {
                        ProviderLogoView(provider: profile.provider, size: 16)
                        Text(profile.provider.displayName)
                    }
                }

                LabeledContent("Connection") {
                    Text(profile.connectionType.displayName)
                        .foregroundStyle(.secondary)
                }

                TextField("Display Name", text: $displayName)
                TextField("Email", text: $email)
                TextField("Plan", text: $planType)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    model.updateProfile(
                        profile,
                        displayName: displayName,
                        email: email,
                        planType: planType
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
