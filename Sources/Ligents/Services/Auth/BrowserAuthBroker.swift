import AppKit
import Foundation

@MainActor
struct BrowserAuthBroker {
    private let callbackScheme = "ligents"

    func start(profile: ProviderProfile) throws -> BrowserAuthSession {
        let sessionId = UUID()
        let callbackURL = try makeCallbackURL(sessionId: sessionId, profileId: profile.id)
        let authorizationURL = try makeAuthorizationURL(
            provider: profile.provider,
            sessionId: sessionId,
            callbackURL: callbackURL
        )

        let session = BrowserAuthSession(
            id: sessionId,
            profileId: profile.id,
            provider: profile.provider,
            state: .opened,
            authorizationURL: authorizationURL,
            callbackURL: callbackURL,
            startedAt: .now,
            completedAt: nil,
            errorMessage: nil
        )

        NSWorkspace.shared.open(authorizationURL)
        return session
    }

    func parseCallback(_ url: URL) throws -> BrowserAuthCallback {
        guard url.scheme == callbackScheme,
              url.host == "auth",
              url.path == "/callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw AdapterFailure.providerUnavailable("Unsupported auth callback URL.")
        }

        let values = try queryValues(from: components)

        guard let sessionValue = values["session_id"],
              let profileValue = values["profile_id"],
              let sessionId = UUID(uuidString: sessionValue),
              let profileId = UUID(uuidString: profileValue)
        else {
            throw AdapterFailure.providerUnavailable("Auth callback is missing session identifiers.")
        }

        let status = values["status"] ?? "success"
        return BrowserAuthCallback(
            sessionId: sessionId,
            profileId: profileId,
            succeeded: status == "success",
            email: values["email"],
            planType: values["plan"],
            message: values["message"]
        )
    }

    private func makeCallbackURL(sessionId: UUID, profileId: UUID) throws -> URL {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = "auth"
        components.path = "/callback"
        components.queryItems = [
            URLQueryItem(name: "session_id", value: sessionId.uuidString),
            URLQueryItem(name: "profile_id", value: profileId.uuidString),
            URLQueryItem(name: "status", value: "success")
        ]

        guard let url = components.url else {
            throw AdapterFailure.providerUnavailable("Could not build auth callback URL.")
        }

        return url
    }

    private func queryValues(from components: URLComponents) throws -> [String: String] {
        var values: [String: String] = [:]

        for item in components.queryItems ?? [] {
            guard let value = item.value else {
                continue
            }

            guard values[item.name] == nil else {
                throw AdapterFailure.providerUnavailable("Auth callback contains duplicate query parameters.")
            }

            values[item.name] = value
        }

        return values
    }

    private func makeAuthorizationURL(
        provider: Provider,
        sessionId: UUID,
        callbackURL: URL
    ) throws -> URL {
        var components = URLComponents(url: provider.browserLoginURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "ligents_state", value: sessionId.uuidString))
        queryItems.append(URLQueryItem(name: "ligents_callback", value: callbackURL.absoluteString))
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw AdapterFailure.providerUnavailable("Could not build provider login URL.")
        }

        return url
    }
}
