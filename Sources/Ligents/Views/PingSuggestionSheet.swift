import SwiftUI

struct PingSuggestionSheet: View {
    @Bindable var model: AppModel
    let profiles: [ProviderProfile]

    @Environment(\.dismiss) private var dismiss
    @State private var wakeTime = PingSuggestionDefaults.wakeTime
    @State private var focusStartTime = PingSuggestionDefaults.focusStartTime
    @State private var weekdays = Set(PingAutomationSettings.defaultWeekdays)
    @State private var strategy: SuggestionLeadStrategy = .balanced

    private let labelWidth: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness Setup")
                        .font(.title2.weight(.semibold))

                    Text("Answer a few questions to build a starting schedule for your Codex profiles.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                SuggestionRow("Wake time", labelWidth: labelWidth) {
                    DatePicker(
                        "",
                        selection: $wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .frame(width: 120, alignment: .leading)
                }

                Divider()

                SuggestionRow("Focus starts", labelWidth: labelWidth) {
                    DatePicker(
                        "",
                        selection: $focusStartTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .frame(width: 120, alignment: .leading)
                }

                Divider()

                SuggestionRow("Lead time", alignment: .top, labelWidth: labelWidth) {
                    ViewThatFits(in: .horizontal) {
                        Picker("Lead time", selection: $strategy) {
                            ForEach(SuggestionLeadStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.displayName)
                                    .tag(strategy)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 330, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Lead time", selection: $strategy) {
                                ForEach(SuggestionLeadStrategy.allCases, id: \.self) { strategy in
                                    Text(strategy.displayName)
                                        .tag(strategy)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Divider()

                SuggestionRow("Days", alignment: .top, labelWidth: labelWidth) {
                    DaySelectionBar(
                        selectedWeekdays: weekdays,
                        onToggle: toggleWeekday
                    )
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Plan")
                    .font(.subheadline.weight(.semibold))

                Text(previewPrimaryLine)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(previewSecondaryLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if pingStartsBeforeWake {
                    Text("May start before wake. Use the wake command after applying if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply to \(profiles.count) profile\(profiles.count == 1 ? "" : "s")") {
                    applySuggestion()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(width: 560)
    }

    private var previewPrimaryLine: String {
        "Ready by \(DisplayFormatters.timeLabel(minutesAfterMidnight: focusStartMinutes)) | \(daySummary)"
    }

    private var previewSecondaryLine: String {
        "\(strategy.summaryLabel) lead. Catch up after wake. Fine-tune later."
    }

    private var pingStartsBeforeWake: Bool {
        focusStartMinutes - strategy.leadTimeMinutes < wakeMinutes
    }

    private var wakeMinutes: Int {
        minutesAfterMidnight(from: wakeTime)
    }

    private var focusStartMinutes: Int {
        minutesAfterMidnight(from: focusStartTime)
    }

    private var daySummary: String {
        let ordered = [2, 3, 4, 5, 6, 7, 1].filter { weekdays.contains($0) }
        let labels = ordered.map(shortWeekday)
        return labels.joined(separator: ", ")
    }

    private func applySuggestion() {
        for profile in profiles {
            var settings = model.pingSettings(for: profile)
            settings.enabled = true
            settings.weekdays = Array(weekdays).sorted()
            settings.readyMinutesAfterMidnight = focusStartMinutes
            settings.leadTimeMinutes = strategy.leadTimeMinutes
            settings.catchUpAfterWake = true
            settings.preventIdleSleep = !pingStartsBeforeWake
            model.updatePingSettings(settings)
        }

        dismiss()
    }

    private func toggleWeekday(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
    }

    private func minutesAfterMidnight(from date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func shortWeekday(_ weekday: Int) -> String {
        let symbols = Calendar.autoupdatingCurrent.shortStandaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return String(symbols[index].prefix(2))
    }
}

private enum SuggestionLeadStrategy: CaseIterable {
    case aggressive
    case balanced
    case conservative

    var displayName: String {
        switch self {
        case .aggressive:
            "2h"
        case .balanced:
            "2.5h"
        case .conservative:
            "3h"
        }
    }

    var leadTimeMinutes: Int {
        switch self {
        case .aggressive:
            120
        case .balanced:
            150
        case .conservative:
            180
        }
    }

    var summaryLabel: String {
        switch self {
        case .aggressive:
            "2h"
        case .balanced:
            "2.5h"
        case .conservative:
            "3h"
        }
    }
}

private enum PingSuggestionDefaults {
    static let wakeTime = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        .addingTimeInterval(TimeInterval(10 * 60 * 60))
    static let focusStartTime = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        .addingTimeInterval(TimeInterval(12 * 60 * 60))
}

private struct SuggestionRow<Content: View>: View {
    let title: String
    let alignment: VerticalAlignment
    let labelWidth: CGFloat
    @ViewBuilder let content: Content

    init(
        _ title: String,
        alignment: VerticalAlignment = .center,
        labelWidth: CGFloat = 170,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.alignment = alignment
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 20) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
