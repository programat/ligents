import AppKit
import Foundation
import UserNotifications

struct NotificationService {
    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationAuthorizationState(settings.authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorizationState {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return await authorizationState()
        } catch {
            return await authorizationState()
        }
    }

    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func sendTestNotification() async {
        await sendTestNotification(soundName: "Default")
    }

    func sendTestNotification(soundName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Ligents"
        content.body = "Notification pipeline is connected."
        content.sound = .default
        content.threadIdentifier = "ligents.notifications.test"
        content.categoryIdentifier = "ligents.test"
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "ligents.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        )

        await SoundPlayer.shared.play(soundName: soundName)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func send(event: NotificationEvent) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.threadIdentifier = "ligents.profile.\(event.profileId.uuidString).\(event.windowKind.rawValue)"
        content.categoryIdentifier = "ligents.usage.\(event.kind.rawValue)"
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "ligents.event.\(event.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        )

        await SoundPlayer.shared.play(soundName: event.soundName)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

private extension NotificationAuthorizationState {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}
