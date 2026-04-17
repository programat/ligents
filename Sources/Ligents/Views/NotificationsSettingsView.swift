import SwiftUI

struct NotificationsSettingsView: View {
    @Bindable var model: AppModel
    @State private var editingRule: AlertRule?
    @State private var expandedProfileIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "Notifications",
                subtitle: "Permission: \(model.notificationAuthorizationState.displayName)"
            ) {
                Button(notificationButtonTitle, systemImage: notificationButtonImage) {
                    model.requestNotificationAuthorization()
                }
                .disabled(model.notificationAuthorizationState.canSendNotifications)

                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refreshNotificationAuthorizationStatus()
                }

                Button("Test", systemImage: "paperplane") {
                    model.sendTestNotification()
                }
                .disabled(!model.notificationAuthorizationState.canSendNotifications)
            }

            Divider()

            if model.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Notification Profiles", systemImage: "bell.slash")
                } description: {
                    Text("Add a profile first to configure alert rules.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(model.profiles) { profile in
                            NotificationProfileSection(
                                profile: profile,
                                rules: model.alertRules(for: profile.id),
                                isExpanded: expandedProfileIDs.contains(profile.id),
                                onToggleExpanded: {
                                    toggleExpanded(profile.id)
                                },
                                onToggleRuleEnabled: { rule, enabled in
                                    model.setAlertRuleEnabled(rule, enabled: enabled)
                                },
                                onEditRule: { rule in
                                    editingRule = rule
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshNotificationAuthorizationStatus()
        }
        .sheet(item: $editingRule) { rule in
            EditAlertRuleSheet(model: model, rule: rule)
        }
    }

    private func toggleExpanded(_ profileID: UUID) {
        if expandedProfileIDs.contains(profileID) {
            expandedProfileIDs.remove(profileID)
        } else {
            expandedProfileIDs.insert(profileID)
        }
    }

    private var notificationButtonTitle: String {
        switch model.notificationAuthorizationState {
        case .denied:
            "Open Settings"
        case .authorized, .provisional, .ephemeral:
            "Enabled"
        case .unknown, .notDetermined:
            "Enable"
        }
    }

    private var notificationButtonImage: String {
        switch model.notificationAuthorizationState {
        case .denied:
            "gear"
        case .authorized, .provisional, .ephemeral:
            "checkmark.circle"
        case .unknown, .notDetermined:
            "bell.badge"
        }
    }
}

private struct NotificationProfileSection: View {
    let profile: ProviderProfile
    let rules: [AlertRule]
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onToggleRuleEnabled: (AlertRule, Bool) -> Void
    let onEditRule: (AlertRule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpanded) {
                HStack(alignment: .center, spacing: 12) {
                    ProviderLogoView(provider: profile.provider, size: 18)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    StatusPill(status: profile.status)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.vertical, 14)

                VStack(alignment: .leading, spacing: 10) {
                    if rules.isEmpty {
                        Text("No notification rules available for this profile yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rules) { rule in
                            NotificationRuleRow(
                                rule: rule,
                                onToggleEnabled: { enabled in
                                    onToggleRuleEnabled(rule, enabled)
                                },
                                onEdit: {
                                    onEditRule(rule)
                                }
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(.easeOut(duration: 0.18), value: isExpanded)
    }

    private var primaryTitle: String {
        if let email = profile.email, !email.isEmpty {
            return email
        }

        return profile.displayName
    }

    private var summaryLine: String {
        let enabledCount = rules.filter(\.enabled).count
        let providerSummary = profile.planType.map { "\(profile.provider.displayName) • \($0)" } ?? profile.provider.displayName

        guard !rules.isEmpty else {
            return "\(providerSummary) • No alert rules"
        }

        let ruleSummary = rules.count == 1 ? "1 alert" : "\(rules.count) alerts"
        let enabledSummary = enabledCount == 1 ? "1 enabled" : "\(enabledCount) enabled"
        return "\(providerSummary) • \(ruleSummary) • \(enabledSummary)"
    }
}

private struct NotificationRuleRow: View {
    let rule: AlertRule
    let onToggleEnabled: (Bool) -> Void
    let onEdit: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(rule.windowKind.displayName)
                                .font(.body.bold())

                            RuleEnabledPill(isEnabled: rule.enabled)
                        }

                        Text(triggerSummary)
                            .font(.body)

                        Text(triggerDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Notifications")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(rule.enabled ? "Enabled" : "Disabled")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(rule.enabled ? .green : .secondary)

                        Toggle(rule.enabled ? "Enabled" : "Disabled", isOn: Binding(
                            get: { rule.enabled },
                            set: { enabled in
                                onToggleEnabled(enabled)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text("Sound")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(rule.soundName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Spacer()

                        Button("Edit Rule") {
                            onEdit()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var triggerSummary: String {
        switch rule.triggerType {
        case .belowPercent:
            if let thresholdPercent = rule.thresholdPercent {
                "Alert when remaining falls below \(Int(thresholdPercent.rounded()))%"
            } else {
                "Alert when remaining falls below the threshold"
            }
        case .beforeReset:
            if let minutesBeforeReset = rule.minutesBeforeReset {
                "Alert \(minutesBeforeReset) minutes before reset"
            } else {
                "Alert before reset"
            }
        case .onExhausted:
            "Alert when the window is exhausted"
        case .onRestored:
            "Alert when usage is restored"
        }
    }

    private var triggerDetail: String {
        switch rule.triggerType {
        case .belowPercent:
            "Triggered as soon as the remaining balance crosses the configured threshold."
        case .beforeReset:
            "Triggered shortly before the reset time for this window."
        case .onExhausted:
            "Triggered when no allowance remains in this window."
        case .onRestored:
            "Triggered after the window becomes available again."
        }
    }
}

private struct RuleEnabledPill: View {
    let isEnabled: Bool

    var body: some View {
        Text(isEnabled ? "Enabled" : "Disabled")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isEnabled ? .green : .secondary)
            .background((isEnabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
    }
}
