import Foundation

struct ProfileUsageSnapshot: Identifiable, Equatable {
    let profile: ProviderProfile
    let usageWindows: [UsageWindow]
    let sessionWindow: UsageWindow?
    let weeklyWindow: UsageWindow?

    var id: UUID { profile.id }

    var sessionRemaining: Double {
        remainingPercent(for: sessionWindow)
    }

    var weeklyRemaining: Double {
        remainingPercent(for: weeklyWindow)
    }

    var recommendationScore: Double {
        let weighted = (sessionRemaining * 0.65) + (weeklyRemaining * 0.35)

        switch profile.status {
        case .active:
            return weighted
        case .syncing:
            return weighted - 5
        case .authenticating:
            return weighted - 10
        case .authRequired, .degraded, .error:
            return weighted - 35
        case .disabled:
            return -1
        }
    }

    var recommendationSummary: String {
        "5h \(Int(sessionRemaining.rounded()))% left  •  Week \(Int(weeklyRemaining.rounded()))% left"
    }

    var displayHandle: String {
        let source = profile.email ?? profile.displayName
        let localPart = source.split(separator: "@").first.map(String.init) ?? source
        return String(localPart.prefix(12))
    }

    private func remainingPercent(for window: UsageWindow?) -> Double {
        if let remaining = window?.remainingPercent {
            return max(0, min(remaining, 100))
        }

        if let used = window?.usedPercent {
            return max(0, min(100 - used, 100))
        }

        return 0
    }
}

enum ProfileInsights {
    static let highlightedKinds: [UsageWindowKind] = [.session, .weekly]

    static func snapshots(
        profiles: [ProviderProfile],
        usageWindows: [UsageWindow]
    ) -> [ProfileUsageSnapshot] {
        snapshots(
            profiles: profiles,
            usageWindowsByProfileID: windowsByProfileID(in: usageWindows)
        )
    }

    static func snapshots(
        profiles: [ProviderProfile],
        usageWindowsByProfileID: [UUID: [UsageWindow]]
    ) -> [ProfileUsageSnapshot] {
        profiles.map { profile in
            let windows = usageWindowsByProfileID[profile.id] ?? []

            return ProfileUsageSnapshot(
                profile: profile,
                usageWindows: windows,
                sessionWindow: primaryWindow(in: windows, kind: .session),
                weeklyWindow: primaryWindow(in: windows, kind: .weekly)
            )
        }
    }

    static func recommended(from snapshots: [ProfileUsageSnapshot]) -> ProfileUsageSnapshot? {
        snapshots
            .filter { !$0.usageWindows.isEmpty && $0.profile.status != .disabled }
            .max { lhs, rhs in
                lhs.recommendationScore < rhs.recommendationScore
            }
    }

    static func windows(for profileId: UUID, in usageWindows: [UsageWindow]) -> [UsageWindow] {
        usageWindows
            .filter { $0.profileId == profileId }
            .sorted(by: isWindowOrderedBefore)
    }

    static func windowsByProfileID(in usageWindows: [UsageWindow]) -> [UUID: [UsageWindow]] {
        Dictionary(grouping: usageWindows, by: \.profileId)
            .mapValues { windows in
                windows.sorted(by: isWindowOrderedBefore)
            }
    }

    static func preferredWindow(in windows: [UsageWindow], kind: UsageWindowKind) -> UsageWindow? {
        windows
            .filter { $0.kind == kind }
            .min(by: isLowerCapacityWindow)
    }

    static func primaryWindow(in windows: [UsageWindow], kind: UsageWindowKind) -> UsageWindow? {
        windows
            .filter { $0.kind == kind }
            .min(by: isPrimaryWindowOrderedBefore)
    }

    static func remainingPercent(for window: UsageWindow?) -> Double? {
        guard let window else {
            return nil
        }

        return remainingPercent(for: window)
    }

    static func remainingPercent(in windows: [UsageWindow], kind: UsageWindowKind) -> Double? {
        remainingPercent(for: primaryWindow(in: windows, kind: kind))
    }

    private static func isWindowOrderedBefore(_ lhs: UsageWindow, _ rhs: UsageWindow) -> Bool {
        if lhs.kind != rhs.kind {
            return sortIndex(for: lhs.kind) < sortIndex(for: rhs.kind)
        }

        return isLowerCapacityWindow(lhs, rhs)
    }

    private static func sortIndex(for kind: UsageWindowKind) -> Int {
        UsageWindowKind.allCases.firstIndex(of: kind) ?? UsageWindowKind.allCases.count
    }

    private static func isPrimaryWindowOrderedBefore(_ lhs: UsageWindow, _ rhs: UsageWindow) -> Bool {
        let lhsIsMain = isMainCodexWindow(lhs)
        let rhsIsMain = isMainCodexWindow(rhs)
        if lhsIsMain != rhsIsMain {
            return lhsIsMain
        }

        return isLowerCapacityWindow(lhs, rhs)
    }

    private static func isMainCodexWindow(_ window: UsageWindow) -> Bool {
        baseProviderWindowID(window.providerWindowId) == "codex"
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

    private static func isLowerCapacityWindow(_ lhs: UsageWindow, _ rhs: UsageWindow) -> Bool {
        if lhs.state == .stale, rhs.state != .stale {
            return false
        }

        if lhs.state != .stale, rhs.state == .stale {
            return true
        }

        let lhsRemaining = remainingPercent(for: lhs) ?? Double.greatestFiniteMagnitude
        let rhsRemaining = remainingPercent(for: rhs) ?? Double.greatestFiniteMagnitude
        if lhsRemaining != rhsRemaining {
            return lhsRemaining < rhsRemaining
        }

        switch (lhs.resetsAt, rhs.resetsAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.providerWindowId < rhs.providerWindowId
        }
    }

    private static func remainingPercent(for window: UsageWindow) -> Double? {
        if let remainingPercent = window.remainingPercent {
            return max(0, min(remainingPercent, 100))
        }

        if let usedPercent = window.usedPercent {
            return max(0, min(100 - usedPercent, 100))
        }

        return nil
    }
}
