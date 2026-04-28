import Foundation

struct CodexAdapter: UsageAdapter {
    let provider: Provider = .codex
    private let runtimeResolver = CodexRuntimeResolver()
    private let clientPool = CodexClientPool.shared
    private let agentProxySettings: AgentProxySettings

    init(agentProxySettings: AgentProxySettings = .disabled) {
        self.agentProxySettings = agentProxySettings.normalized()
    }

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
            codexHome: codexHome,
            agentProxySettings: agentProxySettings
        )
    }

    func normalize(
        result: CodexRateLimitsReadResult,
        profileId: UUID,
        observedAt: Date = .now
    ) -> [UsageWindow] {
        let limits: [(fallbackID: String, limit: CodexRateLimit)]
        if let rateLimitsByLimitId = result.rateLimitsByLimitId {
            limits = rateLimitsByLimitId
                .map { key, limit in (fallbackID: key, limit: limit) }
                .sorted { lhs, rhs in
                    resolvedLimitID(for: lhs.limit, fallbackID: lhs.fallbackID) <
                        resolvedLimitID(for: rhs.limit, fallbackID: rhs.fallbackID)
                }
        } else if let rateLimits = result.rateLimits {
            limits = [(fallbackID: "codex", limit: rateLimits)]
        } else {
            limits = []
        }

        return limits.flatMap { fallbackID, limit -> [UsageWindow] in
            let limitID = resolvedLimitID(for: limit, fallbackID: fallbackID)
            return [
                normalizedWindow(
                    limit: limit,
                    limitID: limitID,
                    bucket: limit.primary,
                    suffix: "primary",
                    fallbackKind: .session,
                    profileId: profileId,
                    observedAt: observedAt
                ),
                normalizedWindow(
                    limit: limit,
                    limitID: limitID,
                    bucket: limit.secondary,
                    suffix: "secondary",
                    fallbackKind: .weekly,
                    profileId: profileId,
                    observedAt: observedAt
                )
            ]
            .compactMap { $0 }
        }
    }

    private func normalizedWindow(
        limit: CodexRateLimit,
        limitID: String,
        bucket: CodexRateLimitWindow?,
        suffix: String,
        fallbackKind: UsageWindowKind,
        profileId: UUID,
        observedAt: Date
    ) -> UsageWindow? {
        guard let bucket else {
            return nil
        }

        let usedPercent = bucket.usedPercent
        let resetsAt = bucket.resetsAt.map { Date(timeIntervalSince1970: $0) }
        let kind = kind(for: bucket, fallbackKind: fallbackKind)
        return UsageWindow(
            id: UUID(),
            profileId: profileId,
            providerWindowId: "\(limitID).\(suffix)",
            label: limit.limitName ?? limitID,
            kind: kind,
            usedPercent: usedPercent,
            remainingPercent: usedPercent.map { max(0, 100 - $0) },
            resetsAt: resetsAt,
            state: state(for: usedPercent),
            observedAt: observedAt,
            rawPayloadRef: nil
        )
    }

    private func resolvedLimitID(for limit: CodexRateLimit, fallbackID: String) -> String {
        if let limitId = limit.limitId, !limitId.isEmpty {
            return limitId
        }

        if !fallbackID.isEmpty {
            return fallbackID
        }

        return "codex"
    }

    private func kind(for bucket: CodexRateLimitWindow, fallbackKind: UsageWindowKind) -> UsageWindowKind {
        guard let duration = bucket.windowDurationMins else {
            return fallbackKind
        }

        if duration >= 28 * 24 * 60 {
            return .monthly
        }

        if duration >= 5 * 24 * 60 {
            return .weekly
        }

        if duration <= 12 * 60 {
            return .session
        }

        return fallbackKind
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
