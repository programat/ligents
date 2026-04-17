import AppKit
import Foundation

@MainActor
@Observable
final class AppModel {
    var profiles: [ProviderProfile] = []
    var usageWindows: [UsageWindow] = []
    var alertRules: [AlertRule] = []
    var snapshots: [SyncSnapshot] = []
    var authSessions: [BrowserAuthSession] = []
    var notificationDedupStates: [NotificationDedupState] = []
    var syncMessage = "Ready"
    var notificationsAuthorized = false
    var notificationAuthorizationState: NotificationAuthorizationState = .unknown

    private let persistenceStore = PersistenceStore()
    private let storageResolver = ProfileStorageResolver()
    private let syncOrchestrator = SyncOrchestrator()
    private let authBroker = BrowserAuthBroker()
    private let notificationRuleEvaluator = NotificationRuleEvaluator()
    private let notificationService = NotificationService()
    private var activeCodexLoginClients: [UUID: CodexAppServerClient] = [:]
    private var codexLoginMonitorTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        load()
        URLCallbackCenter.shared.handler = { [weak self] url in
            self?.handleAuthCallback(url)
        }
        AppActivationCenter.shared.handler = { [weak self] in
            self?.applicationDidBecomeActive()
        }
        refreshNotificationAuthorizationStatus()
        startBackgroundRefreshLoop()
    }

    func usageWindows(for profileId: UUID) -> [UsageWindow] {
        usageWindows
            .filter { $0.profileId == profileId }
            .sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    func alertRules(for profileId: UUID) -> [AlertRule] {
        alertRules
            .filter { $0.profileId == profileId }
            .sorted { $0.windowKind.rawValue < $1.windowKind.rawValue }
    }

    func profileStoragePath(for profile: ProviderProfile) -> String {
        storageResolver.paths(for: profile).root.path
    }

    func providerRuntimePath(for profile: ProviderProfile) -> String {
        let paths = storageResolver.paths(for: profile)
        switch profile.provider {
        case .codex:
            return paths.codexHome?.path ?? "Missing CODEX_HOME"
        case .claude:
            return paths.claudeConfigDirectory?.path ?? "Missing CLAUDE_CONFIG_DIR"
        }
    }

    func providerRuntimePathLabel(for profile: ProviderProfile) -> String {
        switch profile.provider {
        case .codex:
            "CODEX_HOME"
        case .claude:
            "CLAUDE_CONFIG_DIR"
        }
    }

    func latestAuthSession(for profileId: UUID) -> BrowserAuthSession? {
        authSessions
            .filter { $0.profileId == profileId }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    @discardableResult
    func createProfile(
        provider: Provider,
        displayName: String? = nil,
        email: String? = nil,
        planType: String? = nil
    ) -> ProviderProfile? {
        let now = Date.now
        let profileId = UUID()
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = planType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = ProviderProfile(
            id: profileId,
            provider: provider,
            displayName: trimmedName.isEmpty ? "\(provider.displayName) Profile" : trimmedName,
            email: trimmedEmail?.isEmpty == false ? trimmedEmail : nil,
            planType: trimmedPlan?.isEmpty == false ? trimmedPlan : nil,
            status: provider.initialStatus,
            connectionType: provider.defaultConnectionType,
            storageNamespace: "\(provider.rawValue)-\(profileId.uuidString.lowercased())",
            createdAt: now,
            updatedAt: now,
            lastSuccessfulSyncAt: nil,
            lastError: provider.defaultLastError
        )

        do {
            _ = try storageResolver.ensureDirectories(for: profile)
        } catch {
            syncMessage = "Profile storage failed: \(error.localizedDescription)"
            return nil
        }

        profiles.append(profile)
        alertRules.append(contentsOf: defaultAlertRules(for: profileId))
        syncMessage = "Added \(profile.displayName)"
        save()
        return profile
    }

    func addDevelopmentFixture() {
        let now = Date.now
        let profileId = UUID()
        let profile = ProviderProfile(
            id: profileId,
            provider: .codex,
            displayName: "Dev Codex",
            email: "dev@example.com",
            planType: "Pro",
            status: .active,
            connectionType: .codexManagedOAuth,
            storageNamespace: "codex-\(profileId.uuidString.lowercased())",
            createdAt: now,
            updatedAt: now,
            lastSuccessfulSyncAt: now.addingTimeInterval(-120),
            lastError: nil
        )

        let windows = fixtureUsageWindows(for: profileId, observedAt: now)
        do {
            _ = try storageResolver.ensureDirectories(for: profile)
        } catch {
            syncMessage = "Profile storage failed: \(error.localizedDescription)"
            return
        }

        profiles.append(profile)
        usageWindows.append(contentsOf: windows)
        alertRules.append(contentsOf: defaultAlertRules(for: profileId))
        snapshots.append(
            SyncSnapshot(
                id: UUID(),
                profileId: profileId,
                capturedAt: now,
                normalizedWindows: windows,
                adapterVersion: "fixture-1",
                sourceConfidence: .official,
                rawMetadata: ["source": "development-fixture"]
            )
        )
        syncMessage = "Added development fixture"
        save()
    }

    func removeProfile(_ profile: ProviderProfile) {
        codexLoginMonitorTasks[profile.id]?.cancel()
        codexLoginMonitorTasks.removeValue(forKey: profile.id)
        activeCodexLoginClients.removeValue(forKey: profile.id)
        if profile.provider == .codex,
           let codexHome = storageResolver.paths(for: profile).codexHome {
            Task {
                await CodexClientPool.shared.remove(codexHome: codexHome)
            }
        }

        do {
            try storageResolver.removeDirectories(for: profile)
        } catch {
            syncMessage = "Profile storage removal failed: \(error.localizedDescription)"
            save()
            return
        }

        profiles.removeAll { $0.id == profile.id }
        usageWindows.removeAll { $0.profileId == profile.id }
        alertRules.removeAll { $0.profileId == profile.id }
        snapshots.removeAll { $0.profileId == profile.id }
        authSessions.removeAll { $0.profileId == profile.id }
        notificationDedupStates.removeAll { $0.profileId == profile.id }
        syncMessage = "Removed \(profile.displayName)"
        save()
    }

    func setProfileEnabled(_ profile: ProviderProfile, enabled: Bool) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        if !enabled {
            codexLoginMonitorTasks[profile.id]?.cancel()
            codexLoginMonitorTasks.removeValue(forKey: profile.id)
            activeCodexLoginClients.removeValue(forKey: profile.id)
            if profile.provider == .codex,
               let codexHome = storageResolver.paths(for: profile).codexHome {
                Task {
                    await CodexClientPool.shared.remove(codexHome: codexHome)
                }
            }
        }

        profiles[index].status = enabled ? profile.provider.initialStatus : .disabled
        profiles[index].updatedAt = .now
        save()
    }

    func updateProfile(
        _ profile: ProviderProfile,
        displayName: String,
        email: String?,
        planType: String?
    ) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = planType?.trimmingCharacters(in: .whitespacesAndNewlines)

        profiles[index].displayName = trimmedName.isEmpty ? "\(profile.provider.displayName) Profile" : trimmedName
        profiles[index].email = trimmedEmail?.isEmpty == false ? trimmedEmail : nil
        profiles[index].planType = trimmedPlan?.isEmpty == false ? trimmedPlan : nil
        profiles[index].updatedAt = .now
        syncMessage = "Updated \(profiles[index].displayName)"
        save()
    }

    func setAlertRuleEnabled(_ rule: AlertRule, enabled: Bool) {
        guard let index = alertRules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }

        alertRules[index].enabled = enabled
        syncMessage = "Updated alert rule"
        save()
    }

    func updateAlertRule(
        _ rule: AlertRule,
        triggerType: AlertTriggerType,
        thresholdPercent: Double?,
        minutesBeforeReset: Int?,
        soundName: String,
        enabled: Bool
    ) {
        guard let index = alertRules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }

        alertRules[index].triggerType = triggerType
        alertRules[index].thresholdPercent = triggerType == .belowPercent ? thresholdPercent : nil
        alertRules[index].minutesBeforeReset = triggerType == .beforeReset ? minutesBeforeReset : nil
        alertRules[index].soundName = soundName
        alertRules[index].enabled = enabled
        syncMessage = "Updated alert rule"
        save()
    }

    func startBrowserAuth(for profile: ProviderProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        switch profiles[index].provider {
        case .codex:
            let profile = profiles[index]
            Task {
                await startCodexLogin(for: profile)
            }
            return
        case .claude:
            profiles[index].status = .degraded
            profiles[index].lastError = "Claude subscription browser login is not supported by policy. Use Claude Admin API or local transcript import later."
            profiles[index].updatedAt = .now
            syncMessage = "Claude login is gated"
            save()
            return
        }
    }

    func applicationDidBecomeActive() {
        Task {
            await resumePendingCodexAuthentications()
        }
    }

    private func startCustomSchemeBrowserAuth(for profile: ProviderProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        do {
            let session = try authBroker.start(profile: profiles[index])
            authSessions.append(session)
            profiles[index].status = .authenticating
            profiles[index].lastError = "Browser login opened. Waiting for provider callback."
            profiles[index].updatedAt = .now
            syncMessage = "Opened \(profile.provider.displayName) login"
            save()
        } catch {
            profiles[index].status = .error
            profiles[index].lastError = error.localizedDescription
            profiles[index].updatedAt = .now
            syncMessage = "Browser auth failed"
            save()
        }
    }

    private func startCodexLogin(for profile: ProviderProfile) async {
        let profileId = profile.id
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }

        do {
            let storage = try storageResolver.ensureDirectories(for: profiles[index])
            guard let codexHome = storage.codexHome else {
                throw AdapterFailure.storageUnavailable("Codex profile storage is missing CODEX_HOME.")
            }

            let client = try await codexLoginClient(for: profile.id, codexHome: codexHome)
            let result = try await client.loginStart()
            guard let authUrl = result.authUrl,
                  let url = URL(string: authUrl)
            else {
                throw AdapterFailure.providerUnavailable("Codex app-server did not return a login URL.")
            }

            guard let currentIndex = profiles.firstIndex(where: { $0.id == profileId }) else {
                return
            }

            NSWorkspace.shared.open(url)
            profiles[currentIndex].status = .authenticating
            profiles[currentIndex].lastError = "Codex login opened in browser. This profile will update automatically after the callback completes."
            profiles[currentIndex].updatedAt = .now
            syncMessage = "Opened Codex login"
            save()
            scheduleCodexLoginMonitor(for: profileId)
        } catch {
            guard let currentIndex = profiles.firstIndex(where: { $0.id == profileId }) else {
                return
            }

            profiles[currentIndex].status = .authRequired
            profiles[currentIndex].lastError = error.localizedDescription
            profiles[currentIndex].updatedAt = .now
            syncMessage = "Codex login failed"
            save()
        }
    }

    func refreshAll() {
        Task {
            await refreshAllProfiles()
        }
    }

    func requestNotificationAuthorization() {
        if notificationAuthorizationState == .denied {
            notificationService.openSystemNotificationSettings()
            syncMessage = "Opened notification settings"
            return
        }

        Task {
            let state = await notificationService.requestAuthorization()
            await MainActor.run {
                notificationAuthorizationState = state
                notificationsAuthorized = state.canSendNotifications
                syncMessage = "Notifications: \(state.displayName)"
            }
        }
    }

    func refreshNotificationAuthorizationStatus() {
        Task {
            let state = await notificationService.authorizationState()
            await MainActor.run {
                notificationAuthorizationState = state
                notificationsAuthorized = state.canSendNotifications
            }
        }
    }

    func sendTestNotification() {
        Task {
            await notificationService.sendTestNotification()
        }
    }

    func sendTestNotification(soundName: String) {
        previewSound(soundName: soundName)
        Task {
            await notificationService.sendTestNotification(soundName: soundName)
        }
    }

    func previewSound(soundName: String) {
        SoundPlayer.shared.preview(soundName: soundName)
    }

    var persistenceLocation: String {
        persistenceStore.stateFileURL.path
    }

    var profileStorageRoot: String {
        persistenceStore.profilesDirectory.path
    }

    private func load() {
        do {
            let state = try persistenceStore.load() ?? .empty
            profiles = state.profiles
            usageWindows = state.usageWindows
            alertRules = state.alertRules
            snapshots = state.snapshots
            authSessions = state.authSessions
            notificationDedupStates = state.notificationDedupStates
            let originalAlertRules = alertRules
            normalizeAlertRules()
            syncMessage = profiles.isEmpty ? "No profiles" : "Loaded local state"
            if alertRules != originalAlertRules {
                save()
            }
        } catch {
            profiles = []
            usageWindows = []
            alertRules = []
            snapshots = []
            authSessions = []
            notificationDedupStates = []
            syncMessage = "Local state unavailable"
        }
    }

    private func handleAuthCallback(_ url: URL) {
        do {
            let callback = try authBroker.parseCallback(url)
            guard let sessionIndex = authSessions.firstIndex(where: { $0.id == callback.sessionId }),
                  let profileIndex = profiles.firstIndex(where: { $0.id == callback.profileId })
            else {
                syncMessage = "Unknown auth callback"
                return
            }

            authSessions[sessionIndex].completedAt = .now

            if callback.succeeded {
                authSessions[sessionIndex].state = .succeeded
                profiles[profileIndex].email = callback.email ?? profiles[profileIndex].email
                profiles[profileIndex].planType = callback.planType ?? profiles[profileIndex].planType
                profiles[profileIndex].status = .authRequired
                profiles[profileIndex].lastError = "Browser callback received. Token exchange is not implemented yet."
                profiles[profileIndex].updatedAt = .now
                syncMessage = "Browser callback received"
            } else {
                authSessions[sessionIndex].state = .failed
                authSessions[sessionIndex].errorMessage = callback.message ?? "Provider returned a failed auth callback."
                profiles[profileIndex].status = .authRequired
                profiles[profileIndex].lastError = authSessions[sessionIndex].errorMessage
                profiles[profileIndex].updatedAt = .now
                syncMessage = "Browser auth failed"
            }

            save()
        } catch {
            syncMessage = "Invalid auth callback"
        }
    }

    private func refreshAllProfiles() async {
        guard !profiles.isEmpty else {
            syncMessage = "No profiles"
            return
        }

        syncMessage = "Syncing..."
        var completedCount = 0

        for profile in profiles {
            let profileId = profile.id
            guard let profileIndex = profiles.firstIndex(where: { $0.id == profileId }) else {
                continue
            }

            guard profiles[profileIndex].status != .disabled else {
                continue
            }

            let baseProfile = profiles[profileIndex]
            profiles[profileIndex].status = .syncing
            profiles[profileIndex].updatedAt = .now

            let result = await syncOrchestrator.refresh(
                profile: profiles[profileIndex],
                currentUsageWindows: usageWindows(for: profileId)
            )

            guard let currentProfileIndex = profiles.firstIndex(where: { $0.id == profileId }),
                  profiles[currentProfileIndex].status != .disabled
            else {
                continue
            }

            let previousWindows = usageWindows(for: profileId)
            var appliedResult = result

            if result.snapshot == nil,
               result.profile.provider == .codex,
               previousWindows.isEmpty == false,
               profile.displayName == "Dev Codex" {
                appliedResult = simulatedDevelopmentRefresh(
                    profile: result.profile,
                    previousWindows: previousWindows
                )
            }

            appliedResult.profile = mergedProfileAfterRefresh(
                current: profiles[currentProfileIndex],
                base: baseProfile,
                refreshed: appliedResult.profile
            )
            profiles[currentProfileIndex] = appliedResult.profile
            if appliedResult.profile.provider == .codex && appliedResult.profile.status == .active {
                activeCodexLoginClients.removeValue(forKey: profileId)
            }
            usageWindows.removeAll { $0.profileId == profileId }
            usageWindows.append(contentsOf: appliedResult.usageWindows)

            let evaluation = notificationRuleEvaluator.evaluate(
                profile: appliedResult.profile,
                previousWindows: previousWindows,
                newWindows: appliedResult.usageWindows,
                rules: alertRules(for: profileId),
                existingDedupStates: notificationDedupStates.filter { $0.profileId == profileId }
            )

            notificationDedupStates.removeAll { $0.profileId == profileId }
            notificationDedupStates.append(contentsOf: evaluation.dedupStates)

            if notificationAuthorizationState.canSendNotifications {
                for event in evaluation.events {
                    Task {
                        await notificationService.send(event: event)
                    }
                }
            }

            if let snapshot = appliedResult.snapshot {
                snapshots.append(snapshot)
                completedCount += 1
            }
        }

        syncMessage = completedCount == 0 ? "No connected profiles" : "Synced \(completedCount) profile(s)"
        save()
    }

    private func refreshProfile(
        profileId: UUID,
        silent: Bool,
        preserveAuthenticatingOnAuthRequired: Bool
    ) async -> Bool {
        guard let profileIndex = profiles.firstIndex(where: { $0.id == profileId }) else {
            return false
        }

        let profile = profiles[profileIndex]
        guard profile.status != .disabled else {
            return false
        }

        let baseProfile = profile
        let previousWindows = usageWindows(for: profile.id)
        let priorStatus = profile.status
        let now = Date.now

        profiles[profileIndex].status = .syncing
        profiles[profileIndex].updatedAt = now
        if !silent {
            syncMessage = "Syncing \(profile.displayName)..."
        }

        let result = await syncOrchestrator.refresh(
            profile: profiles[profileIndex],
            currentUsageWindows: previousWindows
        )

        guard let currentProfileIndex = profiles.firstIndex(where: { $0.id == profileId }),
              profiles[currentProfileIndex].status != .disabled
        else {
            return false
        }

        var appliedResult = result
        if preserveAuthenticatingOnAuthRequired,
           priorStatus == .authenticating,
           result.profile.status == .authRequired,
           result.snapshot == nil {
            appliedResult.profile.status = .authenticating
            appliedResult.profile.lastError = "Waiting for Codex browser callback..."
            appliedResult.profile.updatedAt = now
        }

        appliedResult.profile = mergedProfileAfterRefresh(
            current: profiles[currentProfileIndex],
            base: baseProfile,
            refreshed: appliedResult.profile
        )
        profiles[currentProfileIndex] = appliedResult.profile
        usageWindows.removeAll { $0.profileId == profile.id }
        usageWindows.append(contentsOf: appliedResult.usageWindows)

        let evaluation = notificationRuleEvaluator.evaluate(
            profile: appliedResult.profile,
            previousWindows: previousWindows,
            newWindows: appliedResult.usageWindows,
            rules: alertRules(for: profile.id),
            existingDedupStates: notificationDedupStates.filter { $0.profileId == profile.id }
        )

        notificationDedupStates.removeAll { $0.profileId == profile.id }
        notificationDedupStates.append(contentsOf: evaluation.dedupStates)

        if notificationAuthorizationState.canSendNotifications {
            for event in evaluation.events {
                Task {
                    await notificationService.send(event: event)
                }
            }
        }

        if let snapshot = appliedResult.snapshot {
            snapshots.append(snapshot)
        }

        if appliedResult.profile.provider == .codex && appliedResult.profile.status == .active {
            codexLoginMonitorTasks[profile.id]?.cancel()
            codexLoginMonitorTasks.removeValue(forKey: profile.id)
            activeCodexLoginClients.removeValue(forKey: profile.id)

            if !silent {
                syncMessage = "Connected \(appliedResult.profile.displayName)"
            }

            save()
            return true
        }

        if !silent {
            syncMessage = appliedResult.snapshot == nil ? "No connected profiles" : "Synced 1 profile"
        }

        save()
        return false
    }

    private func mergedProfileAfterRefresh(
        current: ProviderProfile,
        base: ProviderProfile,
        refreshed: ProviderProfile
    ) -> ProviderProfile {
        var merged = current
        if current.email == base.email {
            merged.email = refreshed.email
        }
        if current.planType == base.planType {
            merged.planType = refreshed.planType
        }
        merged.status = refreshed.status
        merged.lastSuccessfulSyncAt = refreshed.lastSuccessfulSyncAt
        merged.lastError = refreshed.lastError
        merged.updatedAt = refreshed.updatedAt
        return merged
    }

    private func resumePendingCodexAuthentications() async {
        let pendingProfiles = profiles.filter {
            $0.provider == .codex && $0.status == .authenticating
        }

        for profile in pendingProfiles {
            scheduleCodexLoginMonitor(for: profile.id)
        }
    }

    private func scheduleCodexLoginMonitor(for profileId: UUID) {
        codexLoginMonitorTasks[profileId]?.cancel()
        codexLoginMonitorTasks[profileId] = Task { [weak self] in
            guard let self else { return }

            for _ in 0..<45 {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }

                let connected = await self.refreshProfile(
                    profileId: profileId,
                    silent: true,
                    preserveAuthenticatingOnAuthRequired: true
                )

                if connected {
                    return
                }
            }

            await MainActor.run {
                self.finalizeCodexLoginTimeout(for: profileId)
            }
        }
    }

    private func finalizeCodexLoginTimeout(for profileId: UUID) {
        codexLoginMonitorTasks[profileId]?.cancel()
        codexLoginMonitorTasks.removeValue(forKey: profileId)

        guard let profileIndex = profiles.firstIndex(where: { $0.id == profileId }),
              profiles[profileIndex].status == .authenticating
        else {
            return
        }

        profiles[profileIndex].status = .authRequired
        profiles[profileIndex].lastError = "Codex login is still waiting for completion. Try Connect again if the browser flow was interrupted."
        profiles[profileIndex].updatedAt = .now
        syncMessage = "Codex login still pending"
        save()
    }

    private func startBackgroundRefreshLoop() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                guard let self else { return }
                await self.refreshProfilesInBackground()
            }
        }
    }

    private func refreshProfilesInBackground() async {
        let refreshableProfiles = profiles.filter {
            $0.status == .active || $0.status == .authenticating
        }

        guard !refreshableProfiles.isEmpty else {
            return
        }

        for profile in refreshableProfiles {
            _ = await refreshProfile(
                profileId: profile.id,
                silent: true,
                preserveAuthenticatingOnAuthRequired: profile.status == .authenticating
            )
        }
    }

    private func save() {
        do {
            try persistenceStore.save(
                AppPersistenceState(
                    schemaVersion: AppPersistenceState.currentSchemaVersion,
                    profiles: profiles,
                    usageWindows: usageWindows,
                    alertRules: alertRules,
                    snapshots: snapshots,
                    authSessions: authSessions,
                    notificationDedupStates: notificationDedupStates
                )
            )
        } catch {
            syncMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func codexLoginClient(for profileId: UUID, codexHome: URL) async throws -> CodexAppServerClient {
        if let existingClient = activeCodexLoginClients[profileId] {
            return existingClient
        }

        let client = await CodexClientPool.shared.client(
            executablePath: try CodexRuntimeResolver().resolveExecutablePath(),
            codexHome: codexHome
        )

        guard profiles.contains(where: { $0.id == profileId }) else {
            await CodexClientPool.shared.remove(codexHome: codexHome)
            throw CancellationError()
        }

        activeCodexLoginClients[profileId] = client
        return client
    }

    private func fixtureUsageWindows(for profileId: UUID, observedAt: Date) -> [UsageWindow] {
        [
            UsageWindow(
                id: UUID(),
                profileId: profileId,
                providerWindowId: "session",
                label: "Five-hour session",
                kind: .session,
                usedPercent: 42,
                remainingPercent: 58,
                resetsAt: observedAt.addingTimeInterval(84 * 60),
                state: .ok,
                observedAt: observedAt,
                rawPayloadRef: nil
            ),
            UsageWindow(
                id: UUID(),
                profileId: profileId,
                providerWindowId: "weekly",
                label: "Weekly",
                kind: .weekly,
                usedPercent: 71,
                remainingPercent: 29,
                resetsAt: Calendar.current.date(byAdding: .day, value: 3, to: observedAt),
                state: .ok,
                observedAt: observedAt,
                rawPayloadRef: nil
            )
        ]
    }

    private func simulatedDevelopmentRefresh(
        profile: ProviderProfile,
        previousWindows: [UsageWindow]
    ) -> ProfileSyncResult {
        let now = Date.now
        var updatedProfile = profile
        updatedProfile.status = .active
        updatedProfile.lastSuccessfulSyncAt = now
        updatedProfile.lastError = nil
        updatedProfile.updatedAt = now

        let windows = previousWindows.map { window in
            var updatedWindow = window
            updatedWindow.observedAt = now

            if window.kind == .session, let remaining = window.remainingPercent {
                let nextRemaining = remaining <= 5 ? 100 : max(0, remaining - 10)
                updatedWindow.remainingPercent = nextRemaining
                updatedWindow.usedPercent = max(0, 100 - nextRemaining)
            }

            updatedWindow.state = state(for: updatedWindow)
            return updatedWindow
        }

        return ProfileSyncResult(
            profile: updatedProfile,
            usageWindows: windows,
            snapshot: SyncSnapshot(
                id: UUID(),
                profileId: profile.id,
                capturedAt: now,
                normalizedWindows: windows,
                adapterVersion: "dev-fixture-1",
                sourceConfidence: .official,
                rawMetadata: ["source": "development-fixture-refresh"]
            )
        )
    }

    private func defaultAlertRules(for profileId: UUID) -> [AlertRule] {
        [
            AlertRule(
                id: UUID(),
                profileId: profileId,
                windowKind: .session,
                triggerType: .onRestored,
                thresholdPercent: nil,
                minutesBeforeReset: nil,
                soundName: "Funk",
                enabled: true
            ),
            AlertRule(
                id: UUID(),
                profileId: profileId,
                windowKind: .weekly,
                triggerType: .onRestored,
                thresholdPercent: nil,
                minutesBeforeReset: nil,
                soundName: "Glass",
                enabled: true
            )
        ]
    }

    private func normalizeAlertRules() {
        var normalized: [AlertRule] = []

        for profile in profiles {
            let existingRules = alertRules(for: profile.id)

            normalized.append(
                normalizedRule(
                    profileId: profile.id,
                    windowKind: .session,
                    existing: existingRules.first { $0.windowKind == .session },
                    soundName: "Funk"
                )
            )
            normalized.append(
                normalizedRule(
                    profileId: profile.id,
                    windowKind: .weekly,
                    existing: existingRules.first { $0.windowKind == .weekly },
                    soundName: "Glass"
                )
            )
        }

        alertRules = normalized
    }

    private func normalizedRule(
        profileId: UUID,
        windowKind: UsageWindowKind,
        existing: AlertRule?,
        soundName: String
    ) -> AlertRule {
        AlertRule(
            id: existing?.id ?? UUID(),
            profileId: profileId,
            windowKind: windowKind,
            triggerType: existing?.triggerType ?? .onRestored,
            thresholdPercent: existing?.triggerType == .belowPercent ? existing?.thresholdPercent : nil,
            minutesBeforeReset: existing?.triggerType == .beforeReset ? existing?.minutesBeforeReset : nil,
            soundName: existing?.soundName ?? soundName,
            enabled: existing?.enabled ?? true
        )
    }

    private func state(for window: UsageWindow) -> UsageState {
        guard let usedPercent = window.usedPercent else {
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
