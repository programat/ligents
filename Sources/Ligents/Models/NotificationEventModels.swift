import Foundation

enum NotificationEventKind: String, Codable, CaseIterable {
    case belowPercent
    case beforeReset
    case onExhausted
    case onRestored
}

struct NotificationEvent: Equatable, Identifiable {
    var id: String
    var profileId: UUID
    var profileName: String
    var windowKind: UsageWindowKind
    var kind: NotificationEventKind
    var title: String
    var body: String
    var soundName: String
}

struct NotificationDedupState: Codable, Equatable {
    var profileId: UUID
    var windowKind: UsageWindowKind
    var lastState: UsageState
    var lastRemainingPercentBucket: Int?
    var lastBeforeResetBucket: Int?
}
