import Foundation

@MainActor
protocol UsageAdapter {
    var provider: Provider { get }

    func bootstrap(profile: ProviderProfile, storage: ProfileStoragePaths) async throws
    func refreshIdentity(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> IdentityState
    func refreshUsage(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> [UsageWindow]
    func subscribe(profile: ProviderProfile, storage: ProfileStoragePaths) async throws
    func disconnect(profile: ProviderProfile, storage: ProfileStoragePaths) async throws
}
