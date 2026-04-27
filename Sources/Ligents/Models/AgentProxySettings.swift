import Foundation

enum AgentProxyMode: String, Codable, CaseIterable, Identifiable {
    case off
    case http
    case socks5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            "Off"
        case .http:
            "HTTP"
        case .socks5:
            "SOCKS5"
        }
    }

    var defaultPort: Int {
        switch self {
        case .off:
            0
        case .http:
            8080
        case .socks5:
            1080
        }
    }

    var defaultHost: String {
        switch self {
        case .off:
            ""
        case .http, .socks5:
            "127.0.0.1"
        }
    }

    var environmentScheme: String? {
        switch self {
        case .off:
            nil
        case .http:
            "http"
        case .socks5:
            "socks5h"
        }
    }
}

struct AgentProxySettings: Codable, Equatable {
    var mode: AgentProxyMode
    var host: String
    var port: Int
    var username: String
    var password: String
    var bypassLocalAddresses: Bool

    static let disabled = AgentProxySettings(
        mode: .off,
        host: "",
        port: AgentProxyMode.off.defaultPort,
        username: "",
        password: "",
        bypassLocalAddresses: true
    )

    var isEnabled: Bool {
        mode != .off
    }

    var validationMessage: String? {
        guard isEnabled else {
            return nil
        }

        let normalized = normalized()
        if normalized.host.isEmpty {
            return "Proxy host is required."
        }

        if !(1...65_535).contains(normalized.port) {
            return "Proxy port must be between 1 and 65535."
        }

        if normalized.proxyURLString == nil {
            return "Proxy URL could not be built from these values."
        }

        return nil
    }

    var proxyURLString: String? {
        let normalized = normalized()
        guard normalized.isEnabled,
              let scheme = normalized.mode.environmentScheme,
              !normalized.host.isEmpty,
              (1...65_535).contains(normalized.port)
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = normalized.host
        components.port = normalized.port

        if !normalized.username.isEmpty {
            components.user = normalized.username
        }

        if !normalized.password.isEmpty {
            components.password = normalized.password
        }

        return components.url?.absoluteString
    }

    var redactedProxyURLString: String? {
        let normalized = normalized()
        guard normalized.isEnabled,
              let scheme = normalized.mode.environmentScheme,
              !normalized.host.isEmpty,
              (1...65_535).contains(normalized.port)
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = normalized.host
        components.port = normalized.port

        if !normalized.username.isEmpty || !normalized.password.isEmpty {
            components.user = "redacted"
        }

        return components.url?.absoluteString
    }

    var environmentCacheKey: String {
        let normalized = normalized()
        guard normalized.isEnabled else {
            return "proxy-off"
        }

        var credentialHasher = Hasher()
        credentialHasher.combine(normalized.username)
        credentialHasher.combine(normalized.password)

        return [
            normalized.redactedProxyURLString ?? "proxy-invalid",
            "credentials=\(credentialHasher.finalize())",
            "bypassLocal=\(normalized.bypassLocalAddresses)"
        ].joined(separator: "|")
    }

    func normalized() -> AgentProxySettings {
        var normalized = self
        normalized.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.password = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.mode == .off {
            return .disabled
        }

        if let parsed = Self.settingsFromProxyURL(normalized.host) {
            normalized.mode = parsed.mode
            normalized.host = parsed.host
            if let port = parsed.port {
                normalized.port = port
            }
            if let username = parsed.username {
                normalized.username = username
            }
            if let password = parsed.password {
                normalized.password = password
            }
        }

        if normalized.host.isEmpty {
            normalized.host = normalized.mode.defaultHost
        }

        return normalized
    }

    func apply(to environment: inout [String: String]) {
        guard let proxyURLString else {
            return
        }

        let normalized = normalized()

        for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] {
            environment[key] = proxyURLString
        }

        if normalized.mode == .socks5 {
            environment["SOCKS_PROXY"] = proxyURLString
            environment["socks_proxy"] = proxyURLString
        }

        if bypassLocalAddresses {
            let noProxy = "localhost,127.0.0.1,::1"
            environment["NO_PROXY"] = mergedNoProxy(existing: environment["NO_PROXY"], localDefaults: noProxy)
            environment["no_proxy"] = mergedNoProxy(existing: environment["no_proxy"], localDefaults: noProxy)
        }
    }

    private func mergedNoProxy(existing: String?, localDefaults: String) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return localDefaults
        }

        let currentValues = Set(
            existing
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let missingDefaults = localDefaults
            .split(separator: ",")
            .map(String.init)
            .filter { !currentValues.contains($0) }

        guard !missingDefaults.isEmpty else {
            return existing
        }

        return ([existing] + missingDefaults).joined(separator: ",")
    }

    private static func settingsFromProxyURL(_ rawValue: String) -> ParsedProxyURL? {
        guard let components = URLComponents(string: rawValue),
              let scheme = components.scheme?.lowercased(),
              let host = components.host
        else {
            return nil
        }

        let mode: AgentProxyMode
        switch scheme {
        case "http":
            mode = .http
        case "socks5", "socks5h":
            mode = .socks5
        default:
            return nil
        }

        return ParsedProxyURL(
            mode: mode,
            host: host,
            port: components.port,
            username: components.user,
            password: components.password
        )
    }

    private struct ParsedProxyURL {
        var mode: AgentProxyMode
        var host: String
        var port: Int?
        var username: String?
        var password: String?
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case host
        case port
        case username
        case bypassLocalAddresses
    }

    init(
        mode: AgentProxyMode,
        host: String,
        port: Int,
        username: String,
        password: String,
        bypassLocalAddresses: Bool
    ) {
        self.mode = mode
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.bypassLocalAddresses = bypassLocalAddresses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(AgentProxyMode.self, forKey: .mode)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        password = ""
        bypassLocalAddresses = try container.decode(Bool.self, forKey: .bypassLocalAddresses)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(bypassLocalAddresses, forKey: .bypassLocalAddresses)
    }
}
