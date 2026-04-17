import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            AppActivationCenter.shared.handleDidBecomeActive()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        URLCallbackCenter.shared.handle(urls)
    }
}

@main
struct LigentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Ligents", systemImage: "gauge.with.dots.needle.50percent") {
            MenuBarDashboardView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 980, height: 680)
    }
}
