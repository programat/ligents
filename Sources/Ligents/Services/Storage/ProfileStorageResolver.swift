import Foundation

struct ProfileStoragePaths: Equatable {
    var root: URL
    var diagnostics: URL
    var rawPayloads: URL
    var codexHome: URL?
    var claudeConfigDirectory: URL?
}

struct ProfileStorageResolver {
    private let persistenceStore: PersistenceStore

    init(persistenceStore: PersistenceStore = PersistenceStore()) {
        self.persistenceStore = persistenceStore
    }

    func paths(for profile: ProviderProfile) -> ProfileStoragePaths {
        let root = persistenceStore.profileDirectory(namespace: profile.storageNamespace)
        return ProfileStoragePaths(
            root: root,
            diagnostics: root.appending(path: "diagnostics", directoryHint: .isDirectory),
            rawPayloads: root.appending(path: "raw", directoryHint: .isDirectory),
            codexHome: profile.provider == .codex
                ? root.appending(path: "codex-home", directoryHint: .isDirectory)
                : nil,
            claudeConfigDirectory: profile.provider == .claude
                ? root.appending(path: "claude-config", directoryHint: .isDirectory)
                : nil
        )
    }

    func ensureDirectories(for profile: ProviderProfile) throws -> ProfileStoragePaths {
        let paths = paths(for: profile)
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.diagnostics, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.rawPayloads, withIntermediateDirectories: true)

        if let codexHome = paths.codexHome {
            try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        }

        if let claudeConfigDirectory = paths.claudeConfigDirectory {
            try FileManager.default.createDirectory(at: claudeConfigDirectory, withIntermediateDirectories: true)
        }

        return paths
    }

    func removeDirectories(for profile: ProviderProfile) throws {
        try persistenceStore.removeProfileDirectory(namespace: profile.storageNamespace)
    }
}
