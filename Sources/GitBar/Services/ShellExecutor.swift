import Foundation

nonisolated struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let commandNotFound: Bool

    init(stdout: String, stderr: String, exitCode: Int32, commandNotFound: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.commandNotFound = commandNotFound
    }
}

nonisolated private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        self.data = data
    }

    func load() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

nonisolated struct ShellExecutor {
    nonisolated static let defaultTimeout: TimeInterval = 30

    private static func augmentedEnvironment(overrides: [String: String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = CommandSearchPath.augmentedPath(existingPath: env["PATH"], homeDirectory: home)
        env.merge(overrides, uniquingKeysWith: { _, override in override })
        return env
    }

    static func run(
        _ args: [String],
        at directory: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        environmentOverrides: [String: String] = [:]
    ) async -> ShellResult {
        await run("git", args, at: directory, timeout: timeout, environmentOverrides: environmentOverrides)
    }

    static func run(
        _ binary: String,
        _ args: [String],
        at directory: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        environmentOverrides: [String: String] = [:]
    ) async -> ShellResult {
        let environment = augmentedEnvironment(overrides: environmentOverrides)
        guard let executablePath = CommandSearchPath.executablePath(
            for: binary,
            path: environment["PATH"] ?? ""
        ) else {
            return ShellResult(
                stdout: "",
                stderr: "Required command `\(binary)` was not found in GitBar's search path.",
                exitCode: 127,
                commandNotFound: true
            )
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = args
            process.environment = environment

            if let dir = directory, !dir.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutData = ProcessOutputBuffer()
            let stderrData = ProcessOutputBuffer()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                stdoutData.store(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                stderrData.store(stderrPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }

            do {
                try process.run()
            } catch {
                try? stdoutPipe.fileHandleForReading.close()
                try? stderrPipe.fileHandleForReading.close()
                group.wait()
                continuation.resume(returning: ShellResult(stdout: "", stderr: error.localizedDescription, exitCode: -1))
                return
            }

            let timeoutItem = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { terminatedProcess in
                timeoutItem.cancel()
                group.wait()

                let timedOut = terminatedProcess.terminationReason == .uncaughtSignal && terminatedProcess.terminationStatus == SIGTERM
                let stdout = String(data: stdoutData.load(), encoding: .utf8) ?? ""
                let stderr: String
                if timedOut {
                    stderr = "Process timed out after \(Int(timeout))s"
                } else {
                    stderr = String(data: stderrData.load(), encoding: .utf8) ?? ""
                }

                continuation.resume(returning: ShellResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: timedOut ? -1 : terminatedProcess.terminationStatus
                ))
            }
        }
    }
}
