import Foundation

@MainActor
struct AdapterRegistry {
    private let adapters: [Provider: any UsageAdapter]

    init(adapters: [any UsageAdapter] = [CodexAdapter(), ClaudeAdapter()]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0) })
    }

    func adapter(for provider: Provider) throws -> any UsageAdapter {
        guard let adapter = adapters[provider] else {
            throw AdapterFailure.unsupported("No adapter is registered for \(provider.displayName).")
        }

        return adapter
    }
}
