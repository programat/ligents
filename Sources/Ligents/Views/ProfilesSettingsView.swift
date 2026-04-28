import SwiftUI

struct ProfilesSettingsView: View {
    @Bindable var model: AppModel
    @State private var isAddingProfile = false
    @State private var editingProfile: ProviderProfile?
    @State private var expandedProfileIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "Profiles",
                subtitle: "Each account gets its own auth and session namespace."
            ) {
                Button("Add Profile", systemImage: "plus") {
                    isAddingProfile = true
                }
            }

            Divider()

            if model.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Profiles", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Add a Codex profile to create an isolated session and continue in the browser.")
                } actions: {
                    Button("Add Profile") {
                        isAddingProfile = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SettingsLayout.stackSpacing) {
                        ForEach(model.profiles) { profile in
                            ProfileSettingsRow(
                                profile: profile,
                                storagePath: model.profileStoragePath(for: profile),
                                runtimePathLabel: model.providerRuntimePathLabel(for: profile),
                                runtimePath: model.providerRuntimePath(for: profile),
                                usageWindows: model.usageWindows(for: profile.id),
                                authSession: model.latestAuthSession(for: profile.id),
                                isExpanded: expandedProfileIDs.contains(profile.id),
                                onToggleExpanded: {
                                    toggleExpanded(profile.id)
                                },
                                onConnect: {
                                    model.startBrowserAuth(for: profile)
                                },
                                onEdit: {
                                    editingProfile = profile
                                },
                                onToggleEnabled: {
                                    model.setProfileEnabled(profile, enabled: profile.status == .disabled)
                                },
                                onRemove: {
                                    model.removeProfile(profile)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SettingsLayout.horizontalPadding)
                    .padding(.vertical, SettingsLayout.verticalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isAddingProfile) {
            AddProfileSheet(model: model)
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileSheet(model: model, profile: profile)
        }
    }

    private func toggleExpanded(_ profileID: UUID) {
        if expandedProfileIDs.contains(profileID) {
            expandedProfileIDs.remove(profileID)
        } else {
            expandedProfileIDs.insert(profileID)
        }
    }
}

private struct ProfileSettingsRow: View {
    let profile: ProviderProfile
    let storagePath: String
    let runtimePathLabel: String
    let runtimePath: String
    let usageWindows: [UsageWindow]
    let authSession: BrowserAuthSession?
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onToggleEnabled: () -> Void
    let onRemove: () -> Void

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onToggleExpanded) {
                    HStack(alignment: .center, spacing: 12) {
                        ProviderLogoView(provider: profile.provider, size: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.email ?? profile.displayName)
                                .font(.headline)
                                .lineLimit(1)

                            Text(summaryLine)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        StatusPill(status: profile.status)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 16)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("Provider")
                                .foregroundStyle(.secondary)
                            Text(profile.provider.displayName)
                        }

                        GridRow {
                            Text("Connection")
                                .foregroundStyle(.secondary)
                            Text(profile.connectionType.displayName)
                        }

                        GridRow {
                            Text("Storage")
                                .foregroundStyle(.secondary)
                            Text(storagePath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        GridRow {
                            Text(runtimePathLabel)
                                .foregroundStyle(.secondary)
                            Text(runtimePath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.callout)

                    if profile.provider == .claude {
                        Text("Claude stays inactive here because consumer subscription auth and automatic usage tracking are still gated by provider policy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(profile.provider.supportSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if usageWindows.isEmpty {
                        Text("No usage has been observed for this profile yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let lastError = profile.lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let authSession {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Browser auth: \(authSession.state.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Callback: \(authSession.callbackURL.absoluteString)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }

                    HStack(spacing: 8) {
                        Spacer()

                        Button("Connect", action: onConnect)

                        Button("Edit", action: onEdit)

                        Button(profile.status == .disabled ? "Enable" : "Disable", action: onToggleEnabled)

                        Button("Remove", role: .destructive, action: onRemove)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .animation(.smooth(duration: 0.18), value: isExpanded)
    }

    private var summaryLine: String {
        let provider = profile.provider.displayName
        let connection = profile.connectionType.displayName

        if usageWindows.isEmpty {
            return "\(provider) • \(connection)"
        }

        let summary = ProfileInsights.highlightedKinds
            .compactMap { kind -> String? in
                guard let remaining = ProfileInsights.remainingPercent(in: usageWindows, kind: kind) else {
                    return nil
                }

                return "\(kind.displayName) \(Int(remaining.rounded()))% left"
            }
            .joined(separator: " • ")

        if summary.isEmpty {
            return "\(provider) • \(connection)"
        }

        return "\(provider) • \(summary)"
    }
}
