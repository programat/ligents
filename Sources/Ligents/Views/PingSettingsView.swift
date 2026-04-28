import SwiftUI

private enum ReadinessLayout {
    static let contentMaxWidth: CGFloat = SettingsLayout.wideContentMaxWidth
    static let stackSpacing: CGFloat = SettingsLayout.stackSpacing
    static let cardPadding: CGFloat = SettingsLayout.cardPadding
    static let sectionPadding: CGFloat = SettingsLayout.sectionPadding
    static let cardCornerRadius: CGFloat = SettingsLayout.cardCornerRadius
    static let innerCornerRadius: CGFloat = SettingsLayout.rowCornerRadius
}

struct PingSettingsView: View {
    @Bindable var model: AppModel
    @Binding var selection: SettingsSection?
    @State private var showsSuggestionSheet = false
    @State private var expandedProfileIDs: Set<UUID> = []

    private var codexProfiles: [ProviderProfile] {
        model.profiles
            .filter { $0.provider == .codex }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private var wakeSuggestion: WakeScheduleCommandSuggestion? {
        model.nextWakeScheduleSuggestion()
    }

    private var enabledCount: Int {
        codexProfiles.filter { model.pingSettings(for: $0).enabled }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "Keep Ready",
                subtitle: "Keep Codex profiles ready before focused work starts."
            ) {
                if !codexProfiles.isEmpty {
                    Button("Quick Setup", systemImage: "wand.and.stars") {
                        showsSuggestionSheet = true
                    }
                }
            }

            Divider()

            if codexProfiles.isEmpty {
                ContentUnavailableView {
                    Label("No Codex Profiles", systemImage: "wave.3.right.circle")
                } description: {
                    Text("Add a Codex profile to enable keep-ready.")
                } actions: {
                    Button("Open Profiles") {
                        selection = .profiles
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ReadinessLayout.stackSpacing) {
                        PingOverviewCard(
                            profileCount: codexProfiles.count,
                            enabledCount: enabledCount,
                            wakeSuggestion: wakeSuggestion
                        )

                        WakeCommandCard(suggestion: wakeSuggestion)

                        ForEach(codexProfiles) { profile in
                            PingProfileCard(
                                model: model,
                                profile: profile,
                                isExpanded: expandedProfileIDs.contains(profile.id),
                                onToggleExpanded: {
                                    toggleExpanded(profile.id)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: ReadinessLayout.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SettingsLayout.horizontalPadding)
                    .padding(.vertical, SettingsLayout.verticalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showsSuggestionSheet) {
            PingSuggestionSheet(model: model, profiles: codexProfiles)
        }
        .onAppear {
            if expandedProfileIDs.isEmpty, let firstProfile = codexProfiles.first {
                expandedProfileIDs.insert(firstProfile.id)
            }
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

private struct PingProfileCard: View {
    @Bindable var model: AppModel
    let profile: ProviderProfile
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    @State private var showsReliabilityDetails = false

    private var settings: PingAutomationSettings {
        model.pingSettings(for: profile)
    }

    private var plan: PingSchedulePlan {
        model.pingPlan(for: profile)
    }

    private var lastExecution: PingExecutionRecord? {
        model.latestPingExecution(for: profile.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggleExpanded) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: SettingsLayout.rowCornerRadius)
                            .fill(BrandIdentity.accentSoft)

                        ProviderLogoView(provider: profile.provider, size: 18)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.email ?? profile.displayName)
                            .font(.headline)

                        Text(headerSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    StatusPill(status: profile.status)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        toggleBar
                        Button("Ping Now") {
                            model.runPingNow(for: profile)
                        }
                        .disabled(profile.status == .disabled)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        toggleBar
                        Spacer()
                        Button("Ping Now") {
                            model.runPingNow(for: profile)
                        }
                        .disabled(profile.status == .disabled)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 2)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        scheduleSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        statusSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        scheduleSection
                        statusSection
                    }
                }
            }
        }
        .padding(ReadinessLayout.cardPadding)
        .background(SettingsLayout.cardFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius)
                .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
        }
    }

    private var toggleBar: some View {
        Toggle("Enable keep-ready", isOn: binding(for: \.enabled))
            .toggleStyle(.switch)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Schedule")

            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        readyTimeBlock

                        Divider()
                            .frame(height: 48)

                        leadTimeBlock
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        readyTimeBlock
                        leadTimeBlock
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        dayLabel
                            .frame(width: 64, alignment: .leading)

                        daySelection
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        dayLabel
                        daySelection
                    }
                }
            }
            .padding(ReadinessLayout.sectionPadding)
            .background(SettingsLayout.sectionFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.innerCornerRadius))
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Status")

            VStack(alignment: .leading, spacing: 10) {
                Text(plan.summary)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let pingAt = plan.pingAt {
                    PlanRow(label: "Next ping", value: DisplayFormatters.resetLabel(for: pingAt))
                }

                if let readyAt = plan.readyAt {
                    PlanRow(label: "Ready by", value: DisplayFormatters.resetLabel(for: readyAt))
                }

                PlanRow(label: "Plan", value: planTitle)

                if let lastExecution {
                    PlanRow(
                        label: "Last run",
                        value: "\(lastExecution.status.displayName) • \(DisplayFormatters.syncTimestampLabel(for: lastExecution.finishedAt))"
                    )

                    Text(lastExecution.message)
                        .font(.caption)
                        .foregroundStyle(lastExecution.status == .failed ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    PlanRow(label: "Last run", value: "No pings yet")
                }

                reliabilityDisclosure
            }
            .padding(ReadinessLayout.sectionPadding)
            .background(SettingsLayout.sectionFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.innerCornerRadius))
        }
        .disabled(!settings.enabled)
    }

    private var selectedWeekdays: [Int] {
        settings.weekdays
    }

    private var reliabilityDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggleReliabilityDetails) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showsReliabilityDetails ? 90 : 0))
                        .frame(width: 12)

                    Text("Wake & Reliability")
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsReliabilityDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Catch up after wake", isOn: binding(for: \.catchUpAfterWake))
                        .toggleStyle(.checkbox)

                    Toggle("Prevent idle sleep near ping", isOn: binding(for: \.preventIdleSleep))
                        .toggleStyle(.checkbox)

                    if let resetAt = plan.predictedResetAt {
                        PlanRow(label: "Predicted reset", value: DisplayFormatters.resetLabel(for: resetAt))
                    }

                    if let currentResetAt = plan.currentResetAt {
                        PlanRow(label: "Current reset", value: DisplayFormatters.resetLabel(for: currentResetAt))
                    }

                    Text(sleepFootnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showsReliabilityDetails)
    }

    private var readyTimeBinding: Binding<Date> {
        Binding(
            get: {
                dateForTime(minutesAfterMidnight: settings.readyMinutesAfterMidnight)
            },
            set: { newValue in
                var updated = settings
                updated.readyMinutesAfterMidnight = minutesAfterMidnight(from: newValue)
                model.updatePingSettings(updated)
            }
        )
    }

    private var planTitle: String {
        switch plan.state {
        case .disabled:
            return "Disabled"
        case .unsupported:
            return "Unsupported"
        case .alreadyCovered:
            return "Already active"
        case .scheduled:
            return "Scheduled"
        case .due:
            return "Due now"
        }
    }

    private var headerSummary: String {
        switch plan.state {
        case .due:
            return "Ping is due now. Run it now or let Ligents catch it on the next background pass."
        case .scheduled:
            if let pingAt = plan.pingAt {
                return "Next ping \(DisplayFormatters.resetLabel(for: pingAt))."
            }
            return plan.summary
        case .alreadyCovered:
            return "The current 5h window already covers the next intended work slot."
        case .disabled, .unsupported:
            return plan.summary
        }
    }

    private var sleepFootnote: String {
        "Ligents can catch up after wake and prevent idle sleep before a ping. If the Mac is asleep, it resumes after wake."
    }

    private var readyTimeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready by")
                .font(.caption)
                .foregroundStyle(.secondary)

            DatePicker(
                "Ready by",
                selection: readyTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .frame(width: 140, alignment: .leading)
        }
    }

    private var leadTimeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lead time")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Lead Time", selection: binding(for: \.leadTimeMinutes)) {
                ForEach(PingAutomationSettings.supportedLeadTimes, id: \.self) { minutes in
                    Text(leadTitle(minutes: minutes))
                        .tag(minutes)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayLabel: some View {
        Text("Days")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var daySelection: some View {
        DaySelectionBar(
            selectedWeekdays: Set(selectedWeekdays),
            onToggle: toggleWeekday
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func binding<Value>(
        for keyPath: WritableKeyPath<PingAutomationSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                model.pingSettings(for: profile)[keyPath: keyPath]
            },
            set: { newValue in
                var updated = model.pingSettings(for: profile)
                updated[keyPath: keyPath] = newValue
                model.updatePingSettings(updated)
            }
        )
    }

    private func toggleWeekday(_ weekday: Int) {
        var updated = settings
        var weekdays = Set(updated.weekdays)

        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }

        updated.weekdays = Array(weekdays).sorted()
        model.updatePingSettings(updated)
    }

    private func toggleReliabilityDetails() {
        showsReliabilityDetails.toggle()
    }

    private func leadTitle(minutes: Int) -> String {
        switch minutes {
        case 120:
            "2h"
        case 150:
            "2.5h"
        case 180:
            "3h"
        case 210:
            "3.5h"
        default:
            "\(minutes)m"
        }
    }

    private func dateForTime(minutesAfterMidnight: Int) -> Date {
        Calendar.autoupdatingCurrent.startOfDay(for: .now)
            .addingTimeInterval(TimeInterval(minutesAfterMidnight * 60))
    }

    private func minutesAfterMidnight(from date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct PlanRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

private struct PingOverviewCard: View {
    let profileCount: Int
    let enabledCount: Int
    let wakeSuggestion: WakeScheduleCommandSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)

            Text("Pick a ready time. Ligents can catch up after wake and suggest a wake command when needed.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    overviewMetrics
                }

                VStack(spacing: 12) {
                    overviewMetrics
                }
            }
        }
        .padding(ReadinessLayout.cardPadding)
        .background(SettingsLayout.cardFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius)
                .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var overviewMetrics: some View {
        OverviewMetric(title: "Profiles", value: "\(profileCount)")
        OverviewMetric(title: "Enabled", value: "\(enabledCount)")
        OverviewMetric(
            title: "Wake",
            value: wakeSuggestion.map { DisplayFormatters.syncTimestampLabel(for: $0.wakeAt) } ?? "Not needed"
        )
    }
}

private struct WakeCommandCard: View {
    let suggestion: WakeScheduleCommandSuggestion?

    var body: some View {
        if let suggestion {
            expandedCard(suggestion)
        } else {
            compactStatus
        }
    }

    private func expandedCard(_ suggestion: WakeScheduleCommandSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Wake Command")
                    .font(.headline)

                Spacer()

                Text("Reversible")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
            }

            Text("Next scheduled ping: \(suggestion.profileName), \(DisplayFormatters.resetLabel(for: suggestion.wakeAt)). This adds one macOS wake event, not a repeating job.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Use it only if you want the Mac to wake for this slot. The remove command deletes the same event.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            CommandRow(
                title: "Install",
                command: suggestion.installCommand,
                help: "Copy install command"
            )

            CommandRow(
                title: "Remove",
                command: suggestion.removeCommand,
                help: "Copy matching remove command"
            )

            CommandRow(
                title: "Inspect",
                command: suggestion.inspectCommand,
                help: "Copy sched inspection command"
            )
        }
        .padding(ReadinessLayout.cardPadding)
        .background(SettingsLayout.cardFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius)
                .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
        }
    }

    private var compactStatus: some View {
        HStack(spacing: 12) {
            Text("Wake Command")
                .font(.headline)

            Spacer()

            Text("Not needed")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(ReadinessLayout.cardPadding)
        .background(SettingsLayout.cardFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ReadinessLayout.cardCornerRadius)
                .strokeBorder(DashboardPalette.hairline, lineWidth: 1)
        }
    }
}

private struct OverviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ReadinessLayout.sectionPadding)
        .background(SettingsLayout.sectionFill, in: RoundedRectangle(cornerRadius: ReadinessLayout.innerCornerRadius))
    }
}

private struct CommandRow: View {
    let title: String
    let command: String
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Copy") {
                    PasteboardWriter.copy(command)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(help)
            }

            Text(command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(SettingsLayout.sectionFill, in: RoundedRectangle(cornerRadius: SettingsLayout.rowCornerRadius))
        }
    }
}
