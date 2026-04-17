import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SettingsSection = .profiles

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            SettingsDetailPane {
                switch selection {
                case .profiles:
                    ProfilesSettingsView(model: model)
                case .notifications:
                    NotificationsSettingsView(model: model)
                case .diagnostics:
                    DiagnosticsSettingsView(model: model)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 920, minHeight: 620)
    }
}

private struct SettingsDetailPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: 980, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case profiles
    case notifications
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profiles:
            "Profiles"
        case .notifications:
            "Notifications"
        case .diagnostics:
            "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .profiles:
            "person.2"
        case .notifications:
            "bell"
        case .diagnostics:
            "stethoscope"
        }
    }
}
