import Foundation

actor CodexClientPool {
    static let shared = CodexClientPool()

    private var clients: [String: CodexAppServerClient] = [:]

    func client(
        executablePath: String,
        codexHome: URL,
        agentProxySettings: AgentProxySettings = .disabled
    ) -> CodexAppServerClient {
        let normalizedProxySettings = agentProxySettings.normalized()
        let cacheKey = "\(codexHome.path)|\(normalizedProxySettings.environmentCacheKey)"

        if let existing = clients[cacheKey] {
            return existing
        }

        let client = CodexAppServerClient(
            executablePath: executablePath,
            codexHome: codexHome,
            agentProxySettings: normalizedProxySettings
        )
        clients[cacheKey] = client
        return client
    }

    func remove(codexHome: URL) {
        clients = clients.filter { key, _ in
            !key.hasPrefix("\(codexHome.path)|")
        }
    }

    func removeAll() {
        clients.removeAll()
    }
}
