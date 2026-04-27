import Foundation

struct ProfileSyncResult: Equatable {
    var profile: ProviderProfile
    var usageWindows: [UsageWindow]
    var snapshot: SyncSnapshot?
}

@MainActor
struct SyncOrchestrator {
    private let adapterRegistry: AdapterRegistry
    private let storageResolver: ProfileStorageResolver

    init(
        adapterRegistry: AdapterRegistry = AdapterRegistry(),
        storageResolver: ProfileStorageResolver = ProfileStorageResolver()
    ) {
        self.adapterRegistry = adapterRegistry
        self.storageResolver = storageResolver
    }

    func refresh(
        profile: ProviderProfile,
        currentUsageWindows: [UsageWindow],
        agentProxySettings: AgentProxySettings = .disabled
    ) async -> ProfileSyncResult {
        var updatedProfile = profile
        let now = Date.now

        guard profile.status != .disabled else {
            return ProfileSyncResult(profile: profile, usageWindows: currentUsageWindows, snapshot: nil)
        }

        do {
            let storage = try storageResolver.ensureDirectories(for: profile)
            let adapter = try adapterRegistry.adapter(for: profile.provider, agentProxySettings: agentProxySettings)

            updatedProfile.status = .syncing
            updatedProfile.updatedAt = now

            let identity = try await adapter.refreshIdentity(profile: updatedProfile, storage: storage)
            let windows = try await adapter.refreshUsage(profile: updatedProfile, storage: storage)

            updatedProfile.email = identity.email ?? updatedProfile.email
            updatedProfile.planType = identity.planType ?? updatedProfile.planType
            updatedProfile.status = .active
            updatedProfile.lastSuccessfulSyncAt = now
            updatedProfile.lastError = nil
            updatedProfile.updatedAt = now

            let snapshot = SyncSnapshot(
                id: UUID(),
                profileId: profile.id,
                capturedAt: now,
                normalizedWindows: windows,
                adapterVersion: "\(profile.provider.rawValue)-stub-1",
                sourceConfidence: profile.provider == .codex ? .official : .semiOfficial,
                rawMetadata: [
                    "storageRoot": storage.root.path
                ]
            )

            return ProfileSyncResult(profile: updatedProfile, usageWindows: windows, snapshot: snapshot)
        } catch let failure as AdapterFailure {
            updatedProfile.status = failure.profileStatus
            updatedProfile.lastError = failure.localizedDescription
            updatedProfile.updatedAt = now
            return ProfileSyncResult(profile: updatedProfile, usageWindows: currentUsageWindows, snapshot: nil)
        } catch {
            updatedProfile.status = .error
            updatedProfile.lastError = error.localizedDescription
            updatedProfile.updatedAt = now
            return ProfileSyncResult(profile: updatedProfile, usageWindows: currentUsageWindows, snapshot: nil)
        }
    }
}
