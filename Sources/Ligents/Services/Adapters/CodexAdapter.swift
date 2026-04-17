import Foundation

struct CodexAdapter: UsageAdapter {
    let provider: Provider = .codex
    private let runtimeResolver = CodexRuntimeResolver()
    private let clientPool = CodexClientPool.shared

    func bootstrap(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        guard storage.codexHome != nil else {
            throw AdapterFailure.storageUnavailable("Codex profile storage is missing CODEX_HOME.")
        }

        _ = try runtimeResolver.resolveExecutablePath()
    }

    func refreshIdentity(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> IdentityState {
        try await bootstrap(profile: profile, storage: storage)
        guard let codexHome = storage.codexHome else {
            throw AdapterFailure.storageUnavailable("Codex profile storage is missing CODEX_HOME.")
        }

        let client = try await appServerClient(codexHome: codexHome)
        let result = try await client.accountRead(refreshToken: true)

        guard let account = result.account else {
            throw AdapterFailure.authRequired("Codex managed OAuth is not connected yet.")
        }

        return IdentityState(
            profileId: profile.id,
            provider: .codex,
            email: account.email,
            planType: account.planType,
            isAuthenticated: true,
            observedAt: .now,
            message: nil
        )
    }

    func refreshUsage(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> [UsageWindow] {
        try await bootstrap(profile: profile, storage: storage)
        guard let codexHome = storage.codexHome else {
            throw AdapterFailure.storageUnavailable("Codex profile storage is missing CODEX_HOME.")
        }

        let client = try await appServerClient(codexHome: codexHome)
        let result = try await client.rateLimitsRead()
        return normalize(result: result, profileId: profile.id)
    }

    func subscribe(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        try await bootstrap(profile: profile, storage: storage)
        throw AdapterFailure.authRequired("Codex rate-limit updates require a connected account.")
    }

    func disconnect(profile: ProviderProfile, storage: ProfileStoragePaths) async throws {
        try await bootstrap(profile: profile, storage: storage)
        if let codexHome = storage.codexHome {
            await clientPool.remove(codexHome: codexHome)
        }
    }

    func startLogin(profile: ProviderProfile, storage: ProfileStoragePaths) async throws -> URL {
        try await bootstrap(profile: profile, storage: storage)
        guard let codexHome = storage.codexHome else {
            throw AdapterFailure.storageUnavailable("Codex profile storage is missing CODEX_HOME.")
        }

        let client = try await appServerClient(codexHome: codexHome)
        let result = try await client.loginStart()
        guard let authUrl = result.authUrl,
              let url = URL(string: authUrl)
        else {
            throw AdapterFailure.providerUnavailable("Codex app-server did not return a login URL.")
        }

        return url
    }

    private func appServerClient(codexHome: URL) async throws -> CodexAppServerClient {
        await clientPool.client(
            executablePath: try runtimeResolver.resolveExecutablePath(),
            codexHome: codexHome
        )
    }

    private func normalize(result: CodexRateLimitsReadResult, profileId: UUID) -> [UsageWindow] {
        let limits = result.rateLimitsByLimitId?.values.sorted {
            ($0.limitId ?? "") < ($1.limitId ?? "")
        } ?? result.rateLimits.map { [$0] } ?? []

        return limits.flatMap { limit in
            [
                normalizedWindow(limit: limit, bucket: limit.primary, suffix: "primary", kind: .session, profileId: profileId),
                normalizedWindow(limit: limit, bucket: limit.secondary, suffix: "secondary", kind: .weekly, profileId: profileId)
            ]
            .compactMap { $0 }
        }
    }

    private func normalizedWindow(
        limit: CodexRateLimit,
        bucket: CodexRateLimitWindow?,
        suffix: String,
        kind: UsageWindowKind,
        profileId: UUID
    ) -> UsageWindow? {
        guard let bucket else {
            return nil
        }

        let usedPercent = bucket.usedPercent
        let resetsAt = bucket.resetsAt.map { Date(timeIntervalSince1970: $0) }
        let id = limit.limitId ?? UUID().uuidString
        return UsageWindow(
            id: UUID(),
            profileId: profileId,
            providerWindowId: "\(id).\(suffix)",
            label: limit.limitName ?? id,
            kind: kind,
            usedPercent: usedPercent,
            remainingPercent: usedPercent.map { max(0, 100 - $0) },
            resetsAt: resetsAt,
            state: state(for: usedPercent),
            observedAt: .now,
            rawPayloadRef: nil
        )
    }

    private func state(for usedPercent: Double?) -> UsageState {
        guard let usedPercent else {
            return .unknown
        }

        if usedPercent >= 100 {
            return .exhausted
        }

        if usedPercent >= 85 {
            return .warning
        }

        return .ok
    }
}
