import Foundation
import UserNotifications

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated(unsafe) static let shared = NotificationCenterDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
