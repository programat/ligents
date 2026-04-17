import Foundation

enum UsageWindowKind: String, Codable, CaseIterable, Identifiable {
    case session
    case weekly
    case monthly
    case generic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .session:
            "5h"
        case .weekly:
            "Week"
        case .monthly:
            "Month"
        case .generic:
            "Usage"
        }
    }
}

enum UsageState: String, Codable, CaseIterable {
    case ok
    case warning
    case exhausted
    case stale
    case unknown

    var displayName: String {
        switch self {
        case .ok:
            "OK"
        case .warning:
            "Warning"
        case .exhausted:
            "Exhausted"
        case .stale:
            "Stale"
        case .unknown:
            "Unknown"
        }
    }
}

enum AlertTriggerType: String, Codable, CaseIterable {
    case belowPercent
    case beforeReset
    case onExhausted
    case onRestored

    var displayName: String {
        switch self {
        case .belowPercent:
            "Below Percent"
        case .beforeReset:
            "Before Reset"
        case .onExhausted:
            "On Exhausted"
        case .onRestored:
            "On Restored"
        }
    }
}

enum SourceConfidence: String, Codable, CaseIterable {
    case official
    case semiOfficial
    case inferred

    var displayName: String {
        switch self {
        case .official:
            "Official"
        case .semiOfficial:
            "Semi-Official"
        case .inferred:
            "Inferred"
        }
    }
}

struct UsageWindow: Codable, Identifiable, Equatable {
    var id: UUID
    var profileId: UUID
    var providerWindowId: String
    var label: String
    var kind: UsageWindowKind
    var usedPercent: Double?
    var remainingPercent: Double?
    var resetsAt: Date?
    var state: UsageState
    var observedAt: Date
    var rawPayloadRef: String?
}

struct AlertRule: Codable, Identifiable, Equatable {
    var id: UUID
    var profileId: UUID
    var windowKind: UsageWindowKind
    var triggerType: AlertTriggerType
    var thresholdPercent: Double?
    var minutesBeforeReset: Int?
    var soundName: String
    var enabled: Bool
}

struct SyncSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var profileId: UUID
    var capturedAt: Date
    var normalizedWindows: [UsageWindow]
    var adapterVersion: String
    var sourceConfidence: SourceConfidence
    var rawMetadata: [String: String]
}
