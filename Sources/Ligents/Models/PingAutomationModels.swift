import Foundation

enum PingTriggerSource: String, Codable, CaseIterable {
    case manual
    case scheduled
    case wakeCatchUp

    var displayName: String {
        switch self {
        case .manual:
            "Manual"
        case .scheduled:
            "Scheduled"
        case .wakeCatchUp:
            "Wake Catch-Up"
        }
    }
}

enum PingExecutionStatus: String, Codable, CaseIterable {
    case success
    case failed
    case skipped

    var displayName: String {
        switch self {
        case .success:
            "Success"
        case .failed:
            "Failed"
        case .skipped:
            "Skipped"
        }
    }
}

struct PingAutomationSettings: Codable, Identifiable, Equatable {
    static let supportedLeadTimes = [120, 150, 180, 210]
    static let defaultWeekdays = [2, 3, 4, 5, 6]

    var profileId: UUID
    var enabled: Bool
    var weekdays: [Int]
    var readyMinutesAfterMidnight: Int
    var leadTimeMinutes: Int
    var catchUpAfterWake: Bool
    var preventIdleSleep: Bool
    var maxCatchUpDelayMinutes: Int

    var id: UUID { profileId }

    static func makeDefault(for profileId: UUID, enabled: Bool = false) -> PingAutomationSettings {
        PingAutomationSettings(
            profileId: profileId,
            enabled: enabled,
            weekdays: defaultWeekdays,
            readyMinutesAfterMidnight: 10 * 60,
            leadTimeMinutes: 150,
            catchUpAfterWake: true,
            preventIdleSleep: false,
            maxCatchUpDelayMinutes: 75
        )
    }

    func normalized() -> PingAutomationSettings {
        var normalized = self
        let clampedReadyMinutes = min(max(readyMinutesAfterMidnight, 0), (24 * 60) - 1)
        let allowedLead = Self.supportedLeadTimes.contains(leadTimeMinutes) ? leadTimeMinutes : 150
        let normalizedWeekdays = Array(Set(weekdays))
            .filter { (1...7).contains($0) }
            .sorted()

        normalized.weekdays = normalizedWeekdays.isEmpty ? Self.defaultWeekdays : normalizedWeekdays
        normalized.readyMinutesAfterMidnight = clampedReadyMinutes
        normalized.leadTimeMinutes = allowedLead
        normalized.maxCatchUpDelayMinutes = min(max(maxCatchUpDelayMinutes, 5), 180)
        return normalized
    }
}

struct PingExecutionRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var profileId: UUID
    var scheduledFor: Date
    var startedAt: Date
    var finishedAt: Date
    var trigger: PingTriggerSource
    var status: PingExecutionStatus
    var message: String
}

enum PingScheduleState: String, Equatable {
    case disabled
    case unsupported
    case alreadyCovered
    case scheduled
    case due
}

struct PingSchedulePlan: Equatable {
    var profileId: UUID
    var state: PingScheduleState
    var pingAt: Date?
    var readyAt: Date?
    var predictedResetAt: Date?
    var currentResetAt: Date?
    var summary: String

    var isRunnable: Bool {
        state == .due
    }
}
