import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case codex
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex:
            "Codex"
        case .claude:
            "Claude"
        }
    }

    var systemImage: String {
        switch self {
        case .codex:
            "sparkles"
        case .claude:
            "text.bubble"
        }
    }

    var logoResourceName: String {
        switch self {
        case .codex:
            "codex"
        case .claude:
            "claude"
        }
    }

    var usesTemplateLogo: Bool {
        switch self {
        case .codex:
            true
        case .claude:
            false
        }
    }

    var defaultConnectionType: ConnectionType {
        switch self {
        case .codex:
            .codexManagedOAuth
        case .claude:
            .claudeSubscriptionOAuth
        }
    }

    var initialStatus: ProfileStatus {
        switch self {
        case .codex:
            .authRequired
        case .claude:
            .degraded
        }
    }

    var defaultLastError: String? {
        switch self {
        case .codex:
            "Connect this profile with Codex managed OAuth."
        case .claude:
            "Claude automatic usage tracking is gated until a stable usage source is validated."
        }
    }

    var supportSummary: String {
        switch self {
        case .codex:
            "Supported path: managed Codex OAuth and isolated CODEX_HOME."
        case .claude:
            "Gated path: isolated CLAUDE_CONFIG_DIR first, usage extraction after validation."
        }
    }

    var browserLoginURL: URL {
        switch self {
        case .codex:
            URL(string: "https://chatgpt.com/auth/login")!
        case .claude:
            URL(string: "https://claude.ai/login")!
        }
    }
}

enum ProfileStatus: String, Codable, CaseIterable {
    case authenticating
    case active
    case authRequired
    case syncing
    case degraded
    case error
    case disabled

    var displayName: String {
        switch self {
        case .authenticating:
            "Authenticating"
        case .active:
            "Active"
        case .authRequired:
            "Auth Required"
        case .syncing:
            "Syncing"
        case .degraded:
            "Degraded"
        case .error:
            "Error"
        case .disabled:
            "Disabled"
        }
    }
}

enum ConnectionType: String, Codable, CaseIterable {
    case codexManagedOAuth
    case claudeSubscriptionOAuth
    case browserSessionObserver

    var displayName: String {
        switch self {
        case .codexManagedOAuth:
            "Codex Managed OAuth"
        case .claudeSubscriptionOAuth:
            "Claude Subscription OAuth"
        case .browserSessionObserver:
            "Browser Session Observer"
        }
    }
}

struct ProviderProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var provider: Provider
    var displayName: String
    var email: String?
    var planType: String?
    var status: ProfileStatus
    var connectionType: ConnectionType
    var storageNamespace: String
    var createdAt: Date
    var updatedAt: Date
    var lastSuccessfulSyncAt: Date?
    var lastError: String?
}
