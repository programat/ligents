import Foundation

struct ClaudeAdapter: UsageAdapter {
    let provider: Provider = .claude

    func bootstrap(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        guard storage.claudeConfigDirectory != nil else {
            throw AdapterFailure.storageUnavailable("Claude profile storage is missing CLAUDE_CONFIG_DIR.")
        }
    }

    func refreshIdentity(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> IdentityState {
        try await bootstrap(profile: profile, storage: storage)
        throw AdapterFailure.unsupported("Claude automatic usage tracking is gated until a stable usage source is validated.")
    }

    func refreshUsage(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> [UsageWindow] {
        try await bootstrap(profile: profile, storage: storage)
        throw AdapterFailure.unsupported("Claude usage extraction is not enabled in this build.")
    }

    func subscribe(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        try await bootstrap(profile: profile, storage: storage)
        throw AdapterFailure.unsupported("Claude live usage updates are not supported yet.")
    }

    func disconnect(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        try await bootstrap(profile: profile, storage: storage)
    }
}
