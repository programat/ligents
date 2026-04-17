import Foundation

enum BrowserAuthSessionState: String, Codable, CaseIterable {
    case pending
    case opened
    case succeeded
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending:
            "Pending"
        case .opened:
            "Opened"
        case .succeeded:
            "Succeeded"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }
}

struct BrowserAuthSession: Codable, Identifiable, Equatable {
    var id: UUID
    var profileId: UUID
    var provider: Provider
    var state: BrowserAuthSessionState
    var authorizationURL: URL
    var callbackURL: URL
    var startedAt: Date
    var completedAt: Date?
    var errorMessage: String?
}

struct BrowserAuthCallback: Equatable {
    var sessionId: UUID
    var profileId: UUID
    var succeeded: Bool
    var email: String?
    var planType: String?
    var message: String?
}
