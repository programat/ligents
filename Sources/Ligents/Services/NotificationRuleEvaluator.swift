import Foundation

struct NotificationRuleEvaluationResult {
    var events: [NotificationEvent]
    var dedupStates: [NotificationDedupState]
}

struct NotificationRuleEvaluator {
    func evaluate(
        profile: ProviderProfile,
        previousWindows: [UsageWindow],
        newWindows: [UsageWindow],
        rules: [AlertRule],
        existingDedupStates: [NotificationDedupState]
    ) -> NotificationRuleEvaluationResult {
        var dedupMap = Dictionary(
            uniqueKeysWithValues: existingDedupStates.map { (dedupKey(profileId: $0.profileId, windowKind: $0.windowKind), $0) }
        )
        var events: [NotificationEvent] = []

        let previousByKind = preferredWindowsByKind(previousWindows)
        let newByKind = preferredWindowsByKind(newWindows)

        for rule in rules where rule.enabled {
            guard let newWindow = newByKind[rule.windowKind] else {
                continue
            }

            let previousWindow = previousByKind[rule.windowKind]
            let key = dedupKey(profileId: profile.id, windowKind: rule.windowKind)
            let previousDedup = dedupMap[key] ?? NotificationDedupState(
                profileId: profile.id,
                windowKind: rule.windowKind,
                lastState: previousWindow?.state ?? .unknown,
                lastRemainingPercentBucket: previousWindow?.remainingPercent.map(bucketizePercent),
                lastBeforeResetBucket: previousWindow?.resetsAt.flatMap(bucketizeMinutesUntilReset)
            )

            let currentRemainingBucket = newWindow.remainingPercent.map(bucketizePercent)
            let currentBeforeResetBucket = newWindow.resetsAt.flatMap(bucketizeMinutesUntilReset)

            if let event = makeEvent(
                profile: profile,
                window: newWindow,
                previousWindow: previousWindow,
                rule: rule,
                previousDedup: previousDedup,
                currentRemainingBucket: currentRemainingBucket,
                currentBeforeResetBucket: currentBeforeResetBucket
            ) {
                events.append(event)
            }

            dedupMap[key] = NotificationDedupState(
                profileId: profile.id,
                windowKind: rule.windowKind,
                lastState: newWindow.state,
                lastRemainingPercentBucket: currentRemainingBucket,
                lastBeforeResetBucket: currentBeforeResetBucket
            )
        }

        return NotificationRuleEvaluationResult(
            events: events,
            dedupStates: Array(dedupMap.values)
                .sorted { lhs, rhs in
                    if lhs.profileId == rhs.profileId {
                        return lhs.windowKind.rawValue < rhs.windowKind.rawValue
                    }
                    return lhs.profileId.uuidString < rhs.profileId.uuidString
                }
        )
    }

    private func makeEvent(
        profile: ProviderProfile,
        window: UsageWindow,
        previousWindow: UsageWindow?,
        rule: AlertRule,
        previousDedup: NotificationDedupState,
        currentRemainingBucket: Int?,
        currentBeforeResetBucket: Int?
    ) -> NotificationEvent? {
        switch rule.triggerType {
        case .belowPercent:
            guard let thresholdPercent = rule.thresholdPercent,
                  let remainingPercent = window.remainingPercent,
                  remainingPercent <= thresholdPercent
            else {
                return nil
            }

            let thresholdBucket = bucketizePercent(thresholdPercent)
            guard previousDedup.lastRemainingPercentBucket.map({ $0 > thresholdBucket }) ?? true else {
                return nil
            }

            return NotificationEvent(
                id: "\(profile.id.uuidString)-\(window.kind.rawValue)-below-\(thresholdBucket)",
                profileId: profile.id,
                profileName: profile.displayName,
                windowKind: window.kind,
                kind: .belowPercent,
                title: "\(profile.displayName) running low",
                body: "\(window.kind.displayName) remaining is \(Int(remainingPercent.rounded()))%.",
                soundName: rule.soundName
            )

        case .beforeReset:
            guard let minutesBeforeReset = rule.minutesBeforeReset,
                  let resetsAt = window.resetsAt,
                  let currentBucket = currentBeforeResetBucket,
                  currentBucket <= minutesBeforeReset
            else {
                return nil
            }

            guard previousDedup.lastBeforeResetBucket.map({ $0 > minutesBeforeReset }) ?? true else {
                return nil
            }

            return NotificationEvent(
                id: "\(profile.id.uuidString)-\(window.kind.rawValue)-reset-\(currentBucket)",
                profileId: profile.id,
                profileName: profile.displayName,
                windowKind: window.kind,
                kind: .beforeReset,
                title: "\(profile.displayName) resets soon",
                body: "\(window.kind.displayName) resets at \(DisplayFormatters.resetLabel(for: resetsAt)).",
                soundName: rule.soundName
            )

        case .onExhausted:
            guard previousDedup.lastState != .exhausted, window.state == .exhausted else {
                return nil
            }

            return NotificationEvent(
                id: "\(profile.id.uuidString)-\(window.kind.rawValue)-exhausted",
                profileId: profile.id,
                profileName: profile.displayName,
                windowKind: window.kind,
                kind: .onExhausted,
                title: "\(profile.displayName) exhausted",
                body: "\(window.kind.displayName) limit is exhausted.",
                soundName: rule.soundName
            )

        case .onRestored:
            let previousState = previousWindow?.state ?? previousDedup.lastState
            guard previousState == .exhausted,
                  window.state != .exhausted,
                  window.state != .unknown,
                  window.state != .stale
            else {
                return nil
            }

            return NotificationEvent(
                id: "\(profile.id.uuidString)-\(window.kind.rawValue)-restored",
                profileId: profile.id,
                profileName: profile.displayName,
                windowKind: window.kind,
                kind: .onRestored,
                title: "\(profile.displayName) restored",
                body: "\(window.kind.displayName) is available again.",
                soundName: rule.soundName
            )
        }
    }

    private func dedupKey(profileId: UUID, windowKind: UsageWindowKind) -> String {
        "\(profileId.uuidString)-\(windowKind.rawValue)"
    }

    private func preferredWindowsByKind(_ windows: [UsageWindow]) -> [UsageWindowKind: UsageWindow] {
        Dictionary(grouping: windows, by: \.kind)
            .compactMapValues { groupedWindows in
                groupedWindows.sorted(by: isHigherPriorityWindow).first
            }
    }

    private func isHigherPriorityWindow(_ lhs: UsageWindow, _ rhs: UsageWindow) -> Bool {
        let lhsRemaining = resolvedRemainingPercent(for: lhs) ?? Double.greatestFiniteMagnitude
        let rhsRemaining = resolvedRemainingPercent(for: rhs) ?? Double.greatestFiniteMagnitude
        if lhsRemaining != rhsRemaining {
            return lhsRemaining < rhsRemaining
        }

        switch (lhs.resetsAt, rhs.resetsAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.providerWindowId < rhs.providerWindowId
        }
    }

    private func resolvedRemainingPercent(for window: UsageWindow) -> Double? {
        if let remainingPercent = window.remainingPercent {
            return remainingPercent
        }

        if let usedPercent = window.usedPercent {
            return max(0, 100 - usedPercent)
        }

        return nil
    }

    private func bucketizePercent(_ value: Double) -> Int {
        Int(value.rounded(.down))
    }

    private func bucketizeMinutesUntilReset(_ date: Date) -> Int? {
        let minutes = Int(date.timeIntervalSinceNow / 60)
        return minutes >= 0 ? minutes : nil
    }
}
