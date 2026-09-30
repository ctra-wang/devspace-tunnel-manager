import Foundation

struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

actor CommandRunner {
    static let shared = CommandRunner()

    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectory: String? = nil
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var mergedEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            mergedEnvironment[key] = value
        }
        process.environment = mergedEnvironment

        if let currentDirectory, !currentDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            stderr: String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}

actor CommandLocator {
    static let shared = CommandLocator()

    private var cache: [String: String] = [:]

    func resolve(_ command: String, candidates: [String]) async -> String? {
        if let cached = cache[command], FileManager.default.isExecutableFile(atPath: cached) {
            return cached
        }

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            cache[command] = candidate
            return candidate
        }

        do {
            let result = try await CommandRunner.shared.run(
                executable: "/bin/zsh",
                arguments: ["-lc", "command -v \(command)"]
            )
            if result.exitCode == 0,
               let path = result.stdout.split(separator: "\n").first.map(String.init),
               FileManager.default.isExecutableFile(atPath: path) {
                cache[command] = path
                return path
            }
        } catch {
            return nil
        }

        return nil
    }
}
