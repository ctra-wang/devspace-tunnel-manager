import Foundation
import Darwin

struct DevSpaceService {
    static let label = "io.github.devspace-tunnel-manager.devspace"

    private let candidates = [
        "/opt/homebrew/bin/devspace",
        "/usr/local/bin/devspace"
    ]

    private var homeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    private var logDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DevSpaceTunnelManager", isDirectory: true)
    }

    private var stdoutURL: URL {
        logDirectoryURL.appendingPathComponent("devspace.stdout.log")
    }

    private var stderrURL: URL {
        logDirectoryURL.appendingPathComponent("devspace.stderr.log")
    }

    func executablePath() async -> String? {
        await CommandLocator.shared.resolve("devspace", candidates: candidates)
    }

    func status(port: Int) async -> DevSpaceStatus {
        let domain = "gui/\(getuid())/\(Self.label)"

        do {
            let launchResult = try await CommandRunner.shared.run(
                executable: "/bin/launchctl",
                arguments: ["print", domain]
            )

            if launchResult.exitCode == 0 {
                let pid = parseInteger(named: "pid", from: launchResult.stdout)
                let state = parseString(named: "state", from: launchResult.stdout)
                if state == "running" || pid != nil {
                    return DevSpaceStatus(
                        health: .running,
                        pid: pid,
                        command: await executablePath(),
                        detail: "由 launchd 守护",
                        isManaged: true
                    )
                }
            }
        } catch {
            // Continue to external-port detection.
        }

        if let externalPID = await listeningPID(port: port) {
            let command = await commandLine(pid: externalPID)
            return DevSpaceStatus(
                health: .external,
                pid: externalPID,
                command: command,
                detail: "端口由外部进程占用，尚未由本应用守护",
                isManaged: false
            )
        }

        return DevSpaceStatus(
            health: .stopped,
            detail: "DevSpace launchd 服务未运行",
            isManaged: false
        )
    }

    func start(settings: AppSettings) async throws {
        guard (1...65535).contains(settings.port) else {
            throw ManagerError.invalidPort
        }
        guard let devspacePath = await executablePath() else {
            throw ManagerError.commandNotFound("devspace")
        }

        let current = await status(port: settings.port)
        if case .external = current.health, let pid = current.pid {
            throw ManagerError.portOccupied(pid: pid, command: current.command)
        }

        try installLaunchAgent(devspacePath: devspacePath, settings: settings)

        let target = "gui/\(getuid())"
        let service = "\(target)/\(Self.label)"

        _ = try? await CommandRunner.shared.run(
            executable: "/bin/launchctl",
            arguments: ["bootout", target, launchAgentURL.path]
        )

        let bootstrap = try await CommandRunner.shared.run(
            executable: "/bin/launchctl",
            arguments: ["bootstrap", target, launchAgentURL.path]
        )

        guard bootstrap.exitCode == 0 else {
            throw ManagerError.commandFailed(
                bootstrap.combinedOutput.isEmpty ? "无法加载 DevSpace launchd 服务。" : bootstrap.combinedOutput
            )
        }

        let kickstart = try await CommandRunner.shared.run(
            executable: "/bin/launchctl",
            arguments: ["kickstart", "-k", service]
        )

        guard kickstart.exitCode == 0 else {
            throw ManagerError.commandFailed(
                kickstart.combinedOutput.isEmpty ? "DevSpace launchd 服务已经安装，但启动失败。" : kickstart.combinedOutput
            )
        }
    }

    func stop(port: Int) async throws {
        let current = await status(port: port)

        if current.isManaged {
            let result = try await CommandRunner.shared.run(
                executable: "/bin/launchctl",
                arguments: ["bootout", "gui/\(getuid())", launchAgentURL.path]
            )
            if result.exitCode != 0 && !result.combinedOutput.contains("No such process") {
                throw ManagerError.commandFailed(result.combinedOutput)
            }
            return
        }

        if case .external = current.health, let pid = current.pid {
            try await terminateExternalIfSafe(pid: pid, command: current.command)
        }
    }

    func restart(settings: AppSettings) async throws {
        try await stop(port: settings.port)
        try await waitForPortRelease(port: settings.port)
        try await start(settings: settings)
    }

    func takeOver(settings: AppSettings) async throws {
        let current = await status(port: settings.port)
        guard case .external = current.health, let pid = current.pid else {
            try await start(settings: settings)
            return
        }

        if let legacyAgent = legacyLaunchAgentURL(port: settings.port) {
            let result = try await CommandRunner.shared.run(
                executable: "/bin/launchctl",
                arguments: ["bootout", "gui/\(getuid())", legacyAgent.path]
            )
            if result.exitCode != 0 && !result.combinedOutput.contains("No such process") {
                throw ManagerError.commandFailed(result.combinedOutput)
            }
        } else {
            try await terminateExternalIfSafe(pid: pid, command: current.command)
        }

        try await waitForPortRelease(port: settings.port)
        try await start(settings: settings)
    }

    func readRecentLogs(maxBytesPerFile: UInt64 = 48_000) -> String {
        let stdout = tailFile(stdoutURL, maxBytes: maxBytesPerFile)
        let stderr = tailFile(stderrURL, maxBytes: maxBytesPerFile)

        if stdout.isEmpty && stderr.isEmpty {
            return "暂无 launchd DevSpace 日志。\n如果当前显示“外部运行”，接管后日志会出现在这里。"
        }

        var sections: [String] = []
        if !stdout.isEmpty {
            sections.append("── stdout ──\n\(stdout)")
        }
        if !stderr.isEmpty {
            sections.append("── stderr ──\n\(stderr)")
        }
        return sections.joined(separator: "\n\n")
    }

    private func installLaunchAgent(devspacePath: String, settings: AppSettings) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: logDirectoryURL,
            withIntermediateDirectories: true
        )

        let path = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            ProcessInfo.processInfo.environment["PATH"] ?? ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ":")

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [devspacePath, "serve"],
            "EnvironmentVariables": [
                "HOME": homeDirectory,
                "PATH": path,
                "PORT": String(settings.port)
            ],
            "WorkingDirectory": settings.workingDirectory,
            "RunAtLoad": true,
            "KeepAlive": settings.autoRestart,
            "ThrottleInterval": 3,
            "StandardOutPath": stdoutURL.path,
            "StandardErrorPath": stderrURL.path
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func legacyLaunchAgentURL(port: Int) -> URL? {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for file in files where file.pathExtension == "plist" && file != launchAgentURL {
            guard
                let data = try? Data(contentsOf: file),
                let plist = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any],
                let arguments = plist["ProgramArguments"] as? [String],
                arguments.count >= 2,
                URL(fileURLWithPath: arguments[0]).lastPathComponent == "devspace",
                arguments[1] == "serve",
                let environment = plist["EnvironmentVariables"] as? [String: Any],
                String(describing: environment["PORT"] ?? "") == String(port)
            else {
                continue
            }

            return file
        }

        return nil
    }

    private func listeningPID(port: Int) async -> Int? {
        guard (1...65535).contains(port) else { return nil }

        do {
            let result = try await CommandRunner.shared.run(
                executable: "/usr/sbin/lsof",
                arguments: [
                    "-nP",
                    "-t",
                    "-iTCP:\(port)",
                    "-sTCP:LISTEN"
                ]
            )
            guard result.exitCode == 0 else { return nil }
            return result.stdout
                .split(separator: "\n")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .first
        } catch {
            return nil
        }
    }

    private func commandLine(pid: Int) async -> String? {
        do {
            let result = try await CommandRunner.shared.run(
                executable: "/bin/ps",
                arguments: ["-p", String(pid), "-o", "command="]
            )
            guard result.exitCode == 0, !result.stdout.isEmpty else { return nil }
            return result.stdout
        } catch {
            return nil
        }
    }

    private func terminateExternalIfSafe(pid: Int, command: String?) async throws {
        let actualCommand: String?
        if let command {
            actualCommand = command
        } else {
            actualCommand = await commandLine(pid: pid)
        }
        let normalized = actualCommand?.lowercased() ?? ""

        guard normalized.contains("devspace") && normalized.contains("serve") else {
            throw ManagerError.unsafeExternalProcess(pid: pid, command: actualCommand)
        }

        let result = try await CommandRunner.shared.run(
            executable: "/bin/kill",
            arguments: ["-TERM", String(pid)]
        )

        guard result.exitCode == 0 else {
            throw ManagerError.commandFailed(
                result.combinedOutput.isEmpty ? "停止外部 DevSpace 进程失败。" : result.combinedOutput
            )
        }
    }

    private func waitForPortRelease(port: Int) async throws {
        for _ in 0..<20 {
            if await listeningPID(port: port) == nil {
                return
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }

        if let pid = await listeningPID(port: port) {
            throw ManagerError.portOccupied(pid: pid, command: await commandLine(pid: pid))
        }
    }

    private func parseInteger(named key: String, from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.hasPrefix("\(key) =") {
                return Int(cleaned.split(separator: "=").last?.trimmingCharacters(in: .whitespaces) ?? "")
            }
        }
        return nil
    }

    private func parseString(named key: String, from text: String) -> String? {
        for line in text.split(separator: "\n") {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if cleaned.hasPrefix("\(key) =") {
                return cleaned
                    .split(separator: "=", maxSplits: 1)
                    .last?
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func tailFile(_ url: URL, maxBytes: UInt64) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ""
        }
        defer { try? handle.close() }

        do {
            let size = try handle.seekToEnd()
            let start = size > maxBytes ? size - maxBytes : 0
            try handle.seek(toOffset: start)
            let data = try handle.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
