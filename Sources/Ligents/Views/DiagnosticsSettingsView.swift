import SwiftUI

struct DiagnosticsSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "Diagnostics",
                subtitle: "Local state, profile storage, and adapter readiness."
            ) {
                Button("Add Dev Fixture", systemImage: "wrench.and.screwdriver") {
                    model.addDevelopmentFixture()
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                            GridRow {
                                Text("Profiles")
                                    .foregroundStyle(.secondary)
                                Text("\(model.profiles.count)")
                            }

                            GridRow {
                                Text("Usage windows")
                                    .foregroundStyle(.secondary)
                                Text("\(model.usageWindows.count)")
                            }

                            GridRow {
                                Text("State file")
                                    .foregroundStyle(.secondary)
                                Text(model.persistenceLocation)
                                    .textSelection(.enabled)
                            }

                            GridRow {
                                Text("Profile root")
                                    .foregroundStyle(.secondary)
                                Text(model.profileStorageRoot)
                                    .textSelection(.enabled)
                            }

                            GridRow {
                                Text("Notifications")
                                    .foregroundStyle(.secondary)
                                Text(model.notificationAuthorizationState.displayName)
                            }
                        }
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Adapter modes")
                            .font(.headline)

                        HStack {
                            ProviderLogoView(provider: .codex, size: 16)
                            Text("Codex: managed OAuth, isolated CODEX_HOME.")
                        }

                        HStack {
                            ProviderLogoView(provider: .claude, size: 16)
                            Text("Claude: gated until automatic usage extraction is validated.")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
