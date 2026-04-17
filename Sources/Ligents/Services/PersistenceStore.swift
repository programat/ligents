import Foundation

struct AppPersistenceState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var profiles: [ProviderProfile]
    var usageWindows: [UsageWindow]
    var alertRules: [AlertRule]
    var snapshots: [SyncSnapshot]
    var authSessions: [BrowserAuthSession]
    var notificationDedupStates: [NotificationDedupState]

    static var empty: AppPersistenceState {
        AppPersistenceState(
            schemaVersion: currentSchemaVersion,
            profiles: [],
            usageWindows: [],
            alertRules: [],
            snapshots: [],
            authSessions: [],
            notificationDedupStates: []
        )
    }
}

private struct LegacyAppPersistenceState: Codable {
    var profiles: [ProviderProfile]
    var usageWindows: [UsageWindow]
    var alertRules: [AlertRule]
    var snapshots: [SyncSnapshot]
}

struct PersistenceStore {
    var stateFileURL: URL {
        applicationSupportDirectory
            .appending(path: "state.json", directoryHint: .notDirectory)
    }

    var profilesDirectory: URL {
        applicationSupportDirectory
            .appending(path: "Profiles", directoryHint: .isDirectory)
    }

    func profileDirectory(namespace: String) -> URL {
        profilesDirectory
            .appending(path: namespace, directoryHint: .isDirectory)
    }

    func ensureProfileDirectory(namespace: String) throws {
        try FileManager.default.createDirectory(
            at: profileDirectory(namespace: namespace),
            withIntermediateDirectories: true
        )
    }

    func removeProfileDirectory(namespace: String) throws {
        let directory = profileDirectory(namespace: namespace)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        try FileManager.default.removeItem(at: directory)
    }

    private var applicationSupportDirectory: URL {
        URL.applicationSupportDirectory
            .appending(path: AppConstants.appName, directoryHint: .isDirectory)
    }

    func load() throws -> AppPersistenceState? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: stateFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(AppPersistenceState.self, from: data)
        } catch {
            let legacy = try decoder.decode(LegacyAppPersistenceState.self, from: data)
            return AppPersistenceState(
                schemaVersion: AppPersistenceState.currentSchemaVersion,
                profiles: legacy.profiles,
                usageWindows: legacy.usageWindows,
                alertRules: legacy.alertRules,
                snapshots: legacy.snapshots,
                authSessions: [],
                notificationDedupStates: []
            )
        }
    }

    func save(_ state: AppPersistenceState) throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: [.atomic])
    }
}
