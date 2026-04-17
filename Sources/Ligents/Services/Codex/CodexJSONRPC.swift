import Foundation

struct CodexJSONRPCRequest<Params: Encodable>: Encodable {
    var id: Int
    var method: String
    var params: Params?
}

struct CodexJSONRPCNotification<Params: Encodable>: Encodable {
    var method: String
    var params: Params?
}

struct CodexJSONRPCResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    var jsonrpc: String?
    var id: Int?
    var result: Result?
    var error: CodexJSONRPCError?
}

struct CodexJSONRPCError: Decodable, Error, Sendable {
    var code: Int
    var message: String
}

extension CodexJSONRPCError: LocalizedError {
    var errorDescription: String? {
        message
    }
}

struct EmptyCodexParams: Encodable {}

struct CodexInitializeParams: Encodable {
    var clientInfo: CodexClientInfo
    var capabilities: CodexInitializeCapabilities?
}

struct CodexClientInfo: Encodable {
    var name: String
    var title: String?
    var version: String
}

struct CodexInitializeCapabilities: Encodable {
    var experimentalApi: Bool
    var optOutNotificationMethods: [String]?
}

struct CodexInitializeResult: Decodable, Sendable {
    var codexHome: String
    var platformFamily: String
    var platformOs: String
    var userAgent: String
}

struct CodexAccountReadParams: Encodable {
    var refreshToken: Bool
}

struct CodexLoginStartParams: Encodable {
    var type: String
}

struct CodexAccountReadResult: Decodable, Sendable {
    var account: CodexAccount?
    var requiresOpenaiAuth: Bool?
}

struct CodexAccount: Decodable, Sendable {
    var type: String?
    var email: String?
    var planType: String?
}

struct CodexLoginStartResult: Decodable, Sendable {
    var type: String?
    var loginId: String?
    var authUrl: String?
}

struct CodexRateLimitsReadResult: Decodable, Sendable {
    var rateLimits: CodexRateLimit?
    var rateLimitsByLimitId: [String: CodexRateLimit]?
}

struct CodexRateLimit: Decodable, Sendable {
    var limitId: String?
    var limitName: String?
    var primary: CodexRateLimitWindow?
    var secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable, Sendable {
    var usedPercent: Double?
    var windowDurationMins: Double?
    var resetsAt: Double?
}
