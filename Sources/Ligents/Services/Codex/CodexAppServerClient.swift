import Foundation

private struct CodexResponseTimeout: Error {}

private final class CodexResponseContinuationBox<Output: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Output, Error>

    init(_ continuation: CheckedContinuation<Output, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Swift.Result<Output, Error>) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else {
            return
        }

        didResume = true
        continuation.resume(with: result)
    }
}

actor CodexAppServerClient {
    private let executablePath: String
    private let codexHome: URL
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var nextRequestId = 1
    private var initialized = false
    private var initializationInFlight = false
    private var requestInFlight = false
    private let responseTimeoutSeconds: TimeInterval = 15

    init(executablePath: String, codexHome: URL) {
        self.executablePath = executablePath
        self.codexHome = codexHome
    }

    deinit {
        process?.terminate()
    }

    func accountRead(refreshToken: Bool = true) async throws -> CodexAccountReadResult {
        try await initializeIfNeeded()
        return try await request(
            method: "account/read",
            params: CodexAccountReadParams(refreshToken: refreshToken),
            resultType: CodexAccountReadResult.self
        )
    }

    func loginStart() async throws -> CodexLoginStartResult {
        try await initializeIfNeeded()
        return try await request(
            method: "account/login/start",
            params: CodexLoginStartParams(type: "chatgpt"),
            resultType: CodexLoginStartResult.self
        )
    }

    func rateLimitsRead() async throws -> CodexRateLimitsReadResult {
        try await initializeIfNeeded()
        return try await requestNoParams(
            method: "account/rateLimits/read",
            resultType: CodexRateLimitsReadResult.self
        )
    }

    private func requestNoParams<Result: Decodable & Sendable>(
        method: String,
        resultType: Result.Type
    ) async throws -> Result {
        try await request(
            method: method,
            params: Optional<EmptyCodexParams>.none,
            resultType: resultType
        )
    }

    private func initializeIfNeeded() async throws {
        try await waitForInitialization()

        guard !initialized else {
            return
        }

        initializationInFlight = true
        defer {
            initializationInFlight = false
        }

        _ = try await request(
            method: "initialize",
            params: CodexInitializeParams(
                clientInfo: CodexClientInfo(
                    name: "ligents",
                    title: "Ligents",
                    version: "0.1.0"
                ),
                capabilities: CodexInitializeCapabilities(
                    experimentalApi: true,
                    optOutNotificationMethods: nil
                )
            ),
            resultType: CodexInitializeResult.self,
            ensureInitialized: false
        )
        try sendNotification(method: "initialized", params: Optional<EmptyCodexParams>.none)
        initialized = true
    }

    private func sendNotification<Params: Encodable>(
        method: String,
        params: Params?
    ) throws {
        try ensureStarted()

        let envelope = CodexJSONRPCNotification(
            method: method,
            params: params
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)
        guard var line = String(data: data, encoding: .utf8) else {
            throw AdapterFailure.providerUnavailable("Could not encode Codex notification.")
        }

        line.append("\n")
        guard let inputData = line.data(using: .utf8),
              let inputPipe
        else {
            throw AdapterFailure.providerUnavailable("Codex app-server input pipe is unavailable.")
        }

        try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
    }

    private func request<Params: Encodable, Result: Decodable & Sendable>(
        method: String,
        params: Params?,
        resultType: Result.Type,
        ensureInitialized: Bool = true
    ) async throws -> Result {
        try await waitForRequestSlot()
        requestInFlight = true
        defer {
            requestInFlight = false
        }

        try ensureStarted()

        let requestId = nextRequestId
        nextRequestId += 1

        let envelope = CodexJSONRPCRequest(
            id: requestId,
            method: method,
            params: params
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)
        guard var line = String(data: data, encoding: .utf8) else {
            throw AdapterFailure.providerUnavailable("Could not encode Codex request.")
        }

        line.append("\n")
        guard let inputData = line.data(using: .utf8),
              let inputPipe
        else {
            throw AdapterFailure.providerUnavailable("Codex app-server input pipe is unavailable.")
        }

        try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
        return try await readResponse(requestId: requestId, resultType: resultType)
    }

    private func waitForRequestSlot() async throws {
        while requestInFlight {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func waitForInitialization() async throws {
        while initializationInFlight {
            if initialized {
                return
            }

            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func ensureStarted() throws {
        if process?.isRunning == true {
            return
        }

        resetConnectionState(terminate: false)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.environment = mergedEnvironment()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
    }

    private func resetConnectionState(terminate: Bool) {
        if terminate {
            process?.terminate()
        }

        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        process = nil
        inputPipe = nil
        outputPipe = nil
        initialized = false
        initializationInFlight = false
    }

    private func mergedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        return environment
    }

    private func readResponse<Result: Decodable & Sendable>(
        requestId: Int,
        resultType: Result.Type
    ) async throws -> Result {
        guard let outputPipe else {
            throw AdapterFailure.providerUnavailable("Codex app-server output pipe is unavailable.")
        }

        let handle = outputPipe.fileHandleForReading

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let continuationBox = CodexResponseContinuationBox<Result>(continuation)

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let response = try Self.readResponseBlocking(
                            handle: handle,
                            requestId: requestId,
                            resultType: resultType
                        )
                        continuationBox.resume(.success(response))
                    } catch {
                        continuationBox.resume(.failure(error))
                    }
                }

                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + responseTimeoutSeconds) {
                    continuationBox.resume(.failure(CodexResponseTimeout()))
                }
            }
        } catch is CodexResponseTimeout {
            resetConnectionState(terminate: true)
            throw AdapterFailure.providerUnavailable("Timed out waiting for Codex app-server response.")
        }
    }

    private nonisolated static func readResponseBlocking<Result: Decodable & Sendable>(
        handle: FileHandle,
        requestId: Int,
        resultType: Result.Type
    ) throws -> Result {
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                throw AdapterFailure.providerUnavailable("Codex app-server closed before responding.")
            }

            buffer.append(chunk)

            while let lineRange = buffer.firstRange(of: Data([0x0A])) {
                let line = buffer.subdata(in: buffer.startIndex..<lineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...lineRange.lowerBound)

                guard !line.isEmpty else {
                    continue
                }

                if let decoded = try decodeResponseLine(
                    line,
                    requestId: requestId,
                    resultType: resultType
                ) {
                    return decoded
                }
            }
        }
    }

    private nonisolated static func decodeResponseLine<Result: Decodable & Sendable>(
        _ line: Data,
        requestId: Int,
        resultType: Result.Type
    ) throws -> Result? {
        let decoder = JSONDecoder()
        let response = try decoder.decode(CodexJSONRPCResponse<Result>.self, from: line)

        guard response.id == requestId else {
            return nil
        }

        if let error = response.error {
            throw error
        }

        guard let result = response.result else {
            throw AdapterFailure.providerUnavailable("Codex app-server returned an empty response.")
        }

        return result
    }
}
