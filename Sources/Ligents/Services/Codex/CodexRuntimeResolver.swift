import Foundation

struct CodexRuntimeResolver {
    private let candidatePaths = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        "/usr/bin/codex"
    ]

    func resolveExecutablePath() throws -> String {
        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw AdapterFailure.providerUnavailable("Codex executable was not found. Install or bundle Codex before connecting this profile.")
    }
}
