import Foundation

struct WakeScheduleCommandSuggestion: Equatable {
    var profileId: UUID
    var profileName: String
    var wakeAt: Date
    var owner: String
    var installCommand: String
    var removeCommand: String
    var inspectCommand: String
}

struct WakeSchedulePlanner {
    private let formatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy HH:mm:ss"
        self.formatter = formatter
    }

    func nextWakeSuggestion(plans: [(ProviderProfile, PingSchedulePlan)]) -> WakeScheduleCommandSuggestion? {
        let duePlans = plans
            .compactMap { profile, plan -> (ProviderProfile, Date)? in
                guard let pingAt = plan.pingAt, plan.state == .scheduled || plan.state == .due else {
                    return nil
                }
                return (profile, pingAt)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
                }
                return lhs.1 < rhs.1
            }

        guard let (profile, wakeAt) = duePlans.first else {
            return nil
        }

        let owner = "Ligents"
        let formatted = formatter.string(from: wakeAt)
        let quotedDate = "\"\(formatted)\""
        let quotedOwner = "\"\(owner)\""

        return WakeScheduleCommandSuggestion(
            profileId: profile.id,
            profileName: profile.displayName,
            wakeAt: wakeAt,
            owner: owner,
            installCommand: "sudo pmset schedule wakeorpoweron \(quotedDate) \(quotedOwner)",
            removeCommand: "sudo pmset schedule cancel wakeorpoweron \(quotedDate) \(quotedOwner)",
            inspectCommand: "pmset -g sched"
        )
    }
}
