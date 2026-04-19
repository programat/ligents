import SwiftUI

enum SettingsWindowMetrics {
    static let minWidth: CGFloat = 920
    static let idealWidth: CGFloat = 980
    static let maxWidth: CGFloat = 1180
    static let minHeight: CGFloat = 620
    static let idealHeight: CGFloat = 680
    static let maxHeight: CGFloat = 820
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage("settings.selection") private var selectionRawValue = SettingsSection.profiles.rawValue

    private var selection: Binding<SettingsSection?> {
        Binding(
            get: {
                SettingsSection(rawValue: selectionRawValue) ?? .profiles
            },
            set: { newValue in
                selectionRawValue = (newValue ?? .profiles).rawValue
            }
        )
    }

    private var currentSelection: SettingsSection {
        SettingsSection(rawValue: selectionRawValue) ?? .profiles
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            SettingsDetailPane {
                switch currentSelection {
                case .profiles:
                    ProfilesSettingsView(model: model)
                case .pings:
                    PingSettingsView(model: model, selection: selection)
                case .notifications:
                    NotificationsSettingsView(model: model)
                case .diagnostics:
                    DiagnosticsSettingsView(model: model)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: SettingsWindowMetrics.minWidth,
            idealWidth: SettingsWindowMetrics.idealWidth,
            maxWidth: SettingsWindowMetrics.maxWidth,
            minHeight: SettingsWindowMetrics.minHeight,
            idealHeight: SettingsWindowMetrics.idealHeight,
            maxHeight: SettingsWindowMetrics.maxHeight
        )
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
    case pings
    case notifications
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profiles:
            "Profiles"
        case .pings:
            "Readiness"
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
        case .pings:
            "wave.3.right.circle"
        case .notifications:
            "bell"
        case .diagnostics:
            "stethoscope"
        }
    }
}
