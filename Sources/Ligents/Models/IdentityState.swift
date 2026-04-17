import Foundation

struct IdentityState: Codable, Equatable {
    var profileId: UUID
    var provider: Provider
    var email: String?
    var planType: String?
    var isAuthenticated: Bool
    var observedAt: Date
    var message: String?
}

enum AdapterFailure: Error, Equatable {
    case authRequired(String)
    case unsupported(String)
    case notImplemented(String)
    case storageUnavailable(String)
    case providerUnavailable(String)

    var profileStatus: ProfileStatus {
        switch self {
        case .authRequired:
            .authRequired
        case .unsupported, .notImplemented:
            .degraded
        case .storageUnavailable, .providerUnavailable:
            .error
        }
    }
}

extension AdapterFailure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .authRequired(let message),
             .unsupported(let message),
             .notImplemented(let message),
             .storageUnavailable(let message),
             .providerUnavailable(let message):
            message
        }
    }
}
