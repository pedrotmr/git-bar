import Foundation

nonisolated struct ShellResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

nonisolated enum ShellError: Error {
    case timeout
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
            let installHint = binary == "gh" ? " Install GitHub CLI with `brew install gh` and sign in with `gh auth login`." : ""
            return ShellResult(
                stdout: "",
                stderr: "Required command `\(binary)` was not found in GitBar's search path.\(installHint)",
                exitCode: 127
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

            // Collect pipe data asynchronously to avoid blocking
            var stdoutData = Data()
            var stderrData = Data()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            do {
                try process.run()
            } catch {
                // Drain pipes so the group completes
                try? stdoutPipe.fileHandleForReading.close()
                try? stderrPipe.fileHandleForReading.close()
                group.wait()
                continuation.resume(returning: ShellResult(stdout: "", stderr: error.localizedDescription, exitCode: -1))
                return
            }

            // Timeout watchdog
            let timeoutItem = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.terminationHandler = { terminatedProcess in
                timeoutItem.cancel()
                group.wait()

                let timedOut = terminatedProcess.terminationReason == .uncaughtSignal && terminatedProcess.terminationStatus == SIGTERM
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr: String
                if timedOut {
                    stderr = "Process timed out after \(Int(timeout))s"
                } else {
                    stderr = String(data: stderrData, encoding: .utf8) ?? ""
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
