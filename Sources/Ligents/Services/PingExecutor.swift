import Foundation

private struct PingProcessTimedOut: Error {}

private final class PingProcessContinuationBox<Output: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Output, Error>

    init(_ continuation: CheckedContinuation<Output, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Output, Error>) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else {
            return
        }

        didResume = true
        continuation.resume(with: result)
    }
}

struct PingExecutionOutcome {
    var status: PingExecutionStatus
    var message: String
}

struct PingExecutor {
    private let runtimeResolver = CodexRuntimeResolver()
    private let timeoutSeconds: TimeInterval = 90
    private let pingPrompt = "Reply with exactly OK."

    func execute(
        storage: ProfileStoragePaths,
        agentProxySettings: AgentProxySettings = .disabled
    ) async -> PingExecutionOutcome {
        guard let codexHome = storage.codexHome else {
            return PingExecutionOutcome(
                status: .failed,
                message: "Missing CODEX_HOME for this profile."
            )
        }

        do {
            let executablePath = try runtimeResolver.resolveExecutablePath()
            let result = try await runCodexExec(
                executablePath: executablePath,
                codexHome: codexHome,
                agentProxySettings: agentProxySettings
            )
            let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

            guard result.terminationStatus == 0 else {
                return PingExecutionOutcome(
                    status: .failed,
                    message: stderr.isEmpty ? "codex exec exited with status \(result.terminationStatus)." : stderr
                )
            }

            return PingExecutionOutcome(
                status: .success,
                message: stdout.isEmpty ? "Ping completed." : stdout
            )
        } catch is PingProcessTimedOut {
            return PingExecutionOutcome(
                status: .failed,
                message: "Ping timed out while waiting for Codex."
            )
        } catch {
            return PingExecutionOutcome(
                status: .failed,
                message: error.localizedDescription
            )
        }
    }

    private func runCodexExec(
        executablePath: String,
        codexHome: URL,
        agentProxySettings: AgentProxySettings
    ) async throws -> PingCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let continuationBox = PingProcessContinuationBox<PingCommandResult>(continuation)
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            process.arguments = [
                "exec",
                "--skip-git-repo-check",
                "--ephemeral",
                "--sandbox",
                "read-only",
                "--color",
                "never",
                "-C",
                NSTemporaryDirectory(),
                pingPrompt
            ]
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var environment = ProcessInfo.processInfo.environment
            environment["CODEX_HOME"] = codexHome.path
            agentProxySettings.apply(to: &environment)
            process.environment = environment

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuationBox.resume(
                    .success(
                        PingCommandResult(
                            terminationStatus: process.terminationStatus,
                            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                            stderr: String(data: stderrData, encoding: .utf8) ?? ""
                        )
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuationBox.resume(.failure(error))
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                guard process.isRunning else {
                    return
                }

                process.terminate()
                continuationBox.resume(.failure(PingProcessTimedOut()))
            }
        }
    }
}

private struct PingCommandResult: Sendable {
    var terminationStatus: Int32
    var stdout: String
    var stderr: String
}
