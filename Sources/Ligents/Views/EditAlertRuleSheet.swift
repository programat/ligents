import SwiftUI

struct EditAlertRuleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let model: AppModel
    let rule: AlertRule

    @State private var triggerType: AlertTriggerType
    @State private var thresholdText: String
    @State private var minutesBeforeResetText: String
    @State private var soundName: String
    @State private var enabled: Bool

    private let soundNames = [
        "Basso",
        "Blow",
        "Bottle",
        "Frog",
        "Funk",
        "Glass",
        "Hero",
        "Morse",
        "Ping",
        "Pop",
        "Purr",
        "Sosumi",
        "Submarine",
        "Tink"
    ]

    init(model: AppModel, rule: AlertRule) {
        self.model = model
        self.rule = rule
        _triggerType = State(initialValue: rule.triggerType)
        _thresholdText = State(initialValue: rule.thresholdPercent.map { String(Int($0.rounded())) } ?? "20")
        _minutesBeforeResetText = State(initialValue: rule.minutesBeforeReset.map(String.init) ?? "15")
        _soundName = State(initialValue: rule.soundName)
        _enabled = State(initialValue: rule.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Alert Rule")
                    .font(.title2.bold())

                Text("\(rule.windowKind.displayName) notifications")
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    AlertRuleSettingRow("Notifications") {
                        HStack(spacing: 10) {
                            Text(enabled ? "Enabled" : "Disabled")
                                .foregroundStyle(enabled ? .green : .secondary)

                            Toggle(enabled ? "Enabled" : "Disabled", isOn: $enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }

                    Divider()

                    AlertRuleSettingRow("When") {
                        Picker("When", selection: $triggerType) {
                            ForEach(AlertTriggerType.allCases, id: \.self) { type in
                                Text(type.displayName)
                                    .tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 190)
                    }

                    if triggerType == .belowPercent {
                        Divider()

                        AlertRuleSettingRow("Threshold") {
                            HStack(spacing: 8) {
                                TextField("20", text: $thresholdText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 64)

                                Text("% remaining")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if triggerType == .beforeReset {
                        Divider()

                        AlertRuleSettingRow("Lead Time") {
                            HStack(spacing: 8) {
                                TextField("15", text: $minutesBeforeResetText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 64)

                                Text("minutes")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    AlertRuleSettingRow("Sound") {
                        HStack(spacing: 8) {
                            Picker("Sound", selection: $soundName) {
                                ForEach(soundNames, id: \.self) { soundName in
                                    Text(soundName)
                                        .tag(soundName)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 150)
                            .onChange(of: soundName) { _, newValue in
                                model.previewSound(soundName: newValue)
                            }

                            Button("Test") {
                                model.previewSound(soundName: soundName)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 430)
    }

    private func save() {
        model.updateAlertRule(
            rule,
            triggerType: triggerType,
            thresholdPercent: sanitizedThresholdPercent,
            minutesBeforeReset: sanitizedMinutesBeforeReset,
            soundName: soundName,
            enabled: enabled
        )
    }

    private var sanitizedThresholdPercent: Double? {
        guard let value = Double(thresholdText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 20
        }

        return min(100, max(0, value))
    }

    private var sanitizedMinutesBeforeReset: Int? {
        guard let value = Int(minutesBeforeResetText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 15
        }

        return max(1, value)
    }
}

private struct AlertRuleSettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            content
        }
        .padding(.vertical, 10)
    }
}
