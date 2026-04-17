import Foundation

actor CodexClientPool {
    static let shared = CodexClientPool()

    private var clients: [String: CodexAppServerClient] = [:]

    func client(
        executablePath: String,
        codexHome: URL
    ) -> CodexAppServerClient {
        if let existing = clients[codexHome.path] {
            return existing
        }

        let client = CodexAppServerClient(
            executablePath: executablePath,
            codexHome: codexHome
        )
        clients[codexHome.path] = client
        return client
    }

    func remove(codexHome: URL) {
        clients.removeValue(forKey: codexHome.path)
    }
}
