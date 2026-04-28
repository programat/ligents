import Foundation

struct UsageWindowRefreshMergeResult {
    var refreshedWindows: [UsageWindow]
    var displayWindows: [UsageWindow]
}

enum UsageWindowRefreshMerger {
    private static let maximumSessionWindowAge: TimeInterval = 6 * 60 * 60
    private static let maximumWeeklyWindowAge: TimeInterval = 36 * 60 * 60
    private static let maximumSessionResetHorizon: TimeInterval = 6 * 60 * 60
    private static let maximumWeeklyResetHorizon: TimeInterval = 8 * 24 * 60 * 60

    static func merge(
        refreshedWindows: [UsageWindow],
        previousWindows: [UsageWindow],
        now: Date = .now
    ) -> UsageWindowRefreshMergeResult {
        let stableWindows = windowsWithStableIDs(
            refreshedWindows,
            previousWindows: previousWindows
        )
        var mergedWindows = stableWindows
        let refreshedProviderWindowIDs = Set(stableWindows.map(\.providerWindowId))
        let refreshedContinuityKeys = Set(stableWindows.map(continuityKey))

        for previousWindow in previousWindows {
            guard shouldPreserve(
                previousWindow,
                refreshedProviderWindowIDs: refreshedProviderWindowIDs,
                refreshedContinuityKeys: refreshedContinuityKeys,
                now: now
            ) else {
                continue
            }

            var staleWindow = previousWindow
            staleWindow.state = .stale
            mergedWindows.append(staleWindow)
        }

        return UsageWindowRefreshMergeResult(
            refreshedWindows: stableWindows,
            displayWindows: mergedWindows
        )
    }

    private static func windowsWithStableIDs(
        _ windows: [UsageWindow],
        previousWindows: [UsageWindow]
    ) -> [UsageWindow] {
        var idsByProviderWindowID: [String: UUID] = [:]
        for window in previousWindows {
            idsByProviderWindowID[window.providerWindowId] = window.id
        }

        return windows.map { window in
            var stableWindow = window
            if let existingID = idsByProviderWindowID[window.providerWindowId] {
                stableWindow.id = existingID
            }
            return stableWindow
        }
    }

    private static func shouldPreserve(
        _ previousWindow: UsageWindow,
        refreshedProviderWindowIDs: Set<String>,
        refreshedContinuityKeys: Set<String>,
        now: Date
    ) -> Bool {
        guard isRetainableKind(previousWindow.kind),
              let resetsAt = previousWindow.resetsAt,
              !refreshedProviderWindowIDs.contains(previousWindow.providerWindowId)
        else {
            return false
        }

        let resetHorizon = resetsAt.timeIntervalSince(now)
        guard resetHorizon > 0,
              resetHorizon <= maximumResetHorizon(for: previousWindow.kind)
        else {
            return false
        }

        let windowAge = now.timeIntervalSince(previousWindow.observedAt)
        guard windowAge >= 0,
              windowAge <= maximumWindowAge(for: previousWindow.kind)
        else {
            return false
        }

        return !refreshedContinuityKeys.contains(continuityKey(for: previousWindow))
    }

    private static func isRetainableKind(_ kind: UsageWindowKind) -> Bool {
        kind == .session || kind == .weekly
    }

    private static func maximumWindowAge(for kind: UsageWindowKind) -> TimeInterval {
        switch kind {
        case .session:
            maximumSessionWindowAge
        case .weekly:
            maximumWeeklyWindowAge
        case .monthly, .generic:
            0
        }
    }

    private static func maximumResetHorizon(for kind: UsageWindowKind) -> TimeInterval {
        switch kind {
        case .session:
            maximumSessionResetHorizon
        case .weekly:
            maximumWeeklyResetHorizon
        case .monthly, .generic:
            0
        }
    }

    private static func continuityKey(for window: UsageWindow) -> String {
        "\(baseProviderWindowID(window.providerWindowId))|\(window.kind.rawValue)"
    }

    private static func baseProviderWindowID(_ providerWindowId: String) -> String {
        if providerWindowId.hasSuffix(".primary") {
            return String(providerWindowId.dropLast(".primary".count))
        }

        if providerWindowId.hasSuffix(".secondary") {
            return String(providerWindowId.dropLast(".secondary".count))
        }

        return providerWindowId
    }
}
