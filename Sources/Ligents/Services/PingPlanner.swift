import Foundation

struct PingPlanner {
    private let calendar: Calendar
    private let sessionDuration: TimeInterval = 5 * 60 * 60

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func plan(
        profile: ProviderProfile,
        sessionWindow: UsageWindow?,
        settings: PingAutomationSettings,
        now: Date = .now
    ) -> PingSchedulePlan {
        guard profile.provider == .codex else {
            return PingSchedulePlan(
                profileId: profile.id,
                state: .unsupported,
                pingAt: nil,
                readyAt: nil,
                predictedResetAt: nil,
                currentResetAt: sessionWindow?.resetsAt,
                summary: "Ping automation is only supported for Codex profiles."
            )
        }

        let settings = settings.normalized()
        guard settings.enabled else {
            return PingSchedulePlan(
                profileId: profile.id,
                state: .disabled,
                pingAt: nil,
                readyAt: nil,
                predictedResetAt: nil,
                currentResetAt: sessionWindow?.resetsAt,
                summary: "Automation is disabled for this profile."
            )
        }

        let currentResetAt = sessionWindow?.resetsAt
        let slots = upcomingSlots(settings: settings, now: now, limit: 14)

        for slot in slots {
            if let currentResetAt, currentResetAt > now, currentResetAt >= slot.readyAt {
                return PingSchedulePlan(
                    profileId: profile.id,
                    state: .alreadyCovered,
                    pingAt: nil,
                    readyAt: slot.readyAt,
                    predictedResetAt: currentResetAt,
                    currentResetAt: currentResetAt,
                    summary: "The current 5h window already covers the next ready time."
                )
            }

            let effectivePingAt = effectivePingAt(
                basePingAt: slot.pingAt,
                currentResetAt: currentResetAt,
                now: now
            )

            let predictedResetAt = effectivePingAt.addingTimeInterval(sessionDuration)
            let catchUpDeadline = effectivePingAt.addingTimeInterval(TimeInterval(settings.maxCatchUpDelayMinutes * 60))

            if now >= effectivePingAt && now <= catchUpDeadline {
                return PingSchedulePlan(
                    profileId: profile.id,
                    state: .due,
                    pingAt: effectivePingAt,
                    readyAt: slot.readyAt,
                    predictedResetAt: predictedResetAt,
                    currentResetAt: currentResetAt,
                    summary: "The next ping is due now."
                )
            }

            if effectivePingAt > now {
                return PingSchedulePlan(
                    profileId: profile.id,
                    state: .scheduled,
                    pingAt: effectivePingAt,
                    readyAt: slot.readyAt,
                    predictedResetAt: predictedResetAt,
                    currentResetAt: currentResetAt,
                    summary: "The next ping is scheduled."
                )
            }
        }

        return PingSchedulePlan(
            profileId: profile.id,
            state: .scheduled,
            pingAt: nil,
            readyAt: nil,
            predictedResetAt: nil,
            currentResetAt: currentResetAt,
            summary: "No eligible ping slot was found in the next two weeks."
        )
    }

    private func effectivePingAt(
        basePingAt: Date,
        currentResetAt: Date?,
        now: Date
    ) -> Date {
        guard let currentResetAt, currentResetAt > now else {
            return basePingAt
        }

        return max(basePingAt, currentResetAt.addingTimeInterval(1))
    }

    private func upcomingSlots(
        settings: PingAutomationSettings,
        now: Date,
        limit: Int
    ) -> [PingScheduleSlot] {
        var slots: [PingScheduleSlot] = []
        let startOfToday = calendar.startOfDay(for: now)

        for dayOffset in 0..<(limit + 7) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            guard settings.weekdays.contains(weekday) else {
                continue
            }

            let readyAt = date(on: day, minutesAfterMidnight: settings.readyMinutesAfterMidnight)
            let pingAt = readyAt.addingTimeInterval(TimeInterval(-settings.leadTimeMinutes * 60))
            slots.append(PingScheduleSlot(readyAt: readyAt, pingAt: pingAt))

            if slots.count == limit {
                return slots
            }
        }

        return slots
    }

    private func date(
        on day: Date,
        minutesAfterMidnight: Int
    ) -> Date {
        let hour = minutesAfterMidnight / 60
        let minute = minutesAfterMidnight % 60
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }
}

private struct PingScheduleSlot {
    var readyAt: Date
    var pingAt: Date
}
