import Foundation

@MainActor
struct AdapterRegistry {
    private let adapters: [Provider: any UsageAdapter]

    init(adapters: [any UsageAdapter] = []) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0) })
    }

    func adapter(
        for provider: Provider,
        agentProxySettings: AgentProxySettings = .disabled
    ) throws -> any UsageAdapter {
        if let adapter = adapters[provider] {
            return adapter
        }

        switch provider {
        case .codex:
            return CodexAdapter(agentProxySettings: agentProxySettings)
        case .claude:
            return ClaudeAdapter()
        }
    }
}
