import Foundation

enum NotificationAuthorizationState: String, Codable, CaseIterable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var displayName: String {
        switch self {
        case .unknown:
            "Unknown"
        case .notDetermined:
            "Not Requested"
        case .denied:
            "Denied"
        case .authorized:
            "Authorized"
        case .provisional:
            "Provisional"
        case .ephemeral:
            "Ephemeral"
        }
    }

    var canSendNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }
}
