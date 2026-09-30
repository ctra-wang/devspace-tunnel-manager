import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var portText: String
    @Published var workingDirectory: String
    @Published var autoRestart: Bool
    @Published var launchAtLogin: Bool

    @Published private(set) var funnelStatus = FunnelStatus()
    @Published private(set) var devSpaceStatus = DevSpaceStatus()
    @Published private(set) var tailscalePath: String?
    @Published private(set) var devspacePath: String?
    @Published private(set) var logs = "正在读取日志…"
    @Published private(set) var busyAction: String?
    @Published var notice: String?

    private let tailscale = TailscaleService()
    private let devspace = DevSpaceService()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let port = "manager.port"
        static let workingDirectory = "manager.workingDirectory"
        static let autoRestart = "manager.autoRestart"
    }

    init() {
        let storedPort = UserDefaults.standard.integer(forKey: Keys.port)
        portText = String(storedPort == 0 ? 7676 : storedPort)

        let storedDirectory = UserDefaults.standard.string(forKey: Keys.workingDirectory)
        workingDirectory = storedDirectory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if UserDefaults.standard.object(forKey: Keys.autoRestart) == nil {
            autoRestart = true
        } else {
            autoRestart = UserDefaults.standard.bool(forKey: Keys.autoRestart)
        }

        launchAtLogin = LoginItemService.isEnabled
    }

    var port: Int? {
        guard let value = Int(portText), (1...65535).contains(value) else {
            return nil
        }
        return value
    }

    var hasValidWorkingDirectory: Bool {
        let path = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    var settings: AppSettings? {
        guard let port, hasValidWorkingDirectory else { return nil }
        return AppSettings(
            port: port,
            workingDirectory: workingDirectory,
            autoRestart: autoRestart
        )
    }

    var overallHealthy: Bool {
        if case .running = funnelStatus.health,
           case .running = devSpaceStatus.health {
            return true
        }
        return false
    }

    var portValidationMessage: String? {
        port == nil ? "请输入 1–65535 之间的端口" : nil
    }

    var workingDirectoryValidationMessage: String? {
        if workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请选择 DevSpace 工作目录"
        }
        return hasValidWorkingDirectory ? nil : "所选目录不存在或不可访问"
    }

    func setWorkingDirectory(_ path: String) {
        workingDirectory = path
        defaults.set(path, forKey: Keys.workingDirectory)
        notice = "DevSpace 工作目录已更新。"
    }

    func saveSettings() {
        guard let port else {
            notice = ManagerError.invalidPort.localizedDescription
            return
        }
        guard hasValidWorkingDirectory else {
            notice = workingDirectoryValidationMessage ?? "请选择有效的 DevSpace 工作目录。"
            return
        }

        defaults.set(port, forKey: Keys.port)
        defaults.set(workingDirectory, forKey: Keys.workingDirectory)
        defaults.set(autoRestart, forKey: Keys.autoRestart)
        notice = "设置已保存。DevSpace 守护配置会在下次启动或重启时应用。"
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            launchAtLogin = LoginItemService.isEnabled
            notice = enabled ? "已设置登录后自动启动管理器。" : "已取消登录后自动启动。"
        } catch {
            launchAtLogin = LoginItemService.isEnabled
            notice = "修改登录启动失败：\(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard let port else { return }

        async let tsPath = tailscale.executablePath()
        async let dsPath = devspace.executablePath()
        async let funnel = tailscale.status()
        async let dev = devspace.status(port: port)

        tailscalePath = await tsPath
        devspacePath = await dsPath
        funnelStatus = await funnel
        devSpaceStatus = await dev
        logs = devspace.readRecentLogs()
    }

    func startTailscale() async {
        guard let port else {
            notice = ManagerError.invalidPort.localizedDescription
            return
        }

        await perform("tailscale-start") {
            try await tailscale.start(port: port)
        }
    }

    func resetTailscale() async {
        await perform("tailscale-reset") {
            try await tailscale.reset()
        }
    }

    func startDevSpace() async {
        guard let settings else {
            notice = configurationValidationMessage
            return
        }
        saveSettings()

        await perform("devspace-start") {
            try await devspace.start(settings: settings)
        }
    }

    func stopDevSpace() async {
        guard let port else {
            notice = ManagerError.invalidPort.localizedDescription
            return
        }

        await perform("devspace-stop") {
            try await devspace.stop(port: port)
        }
    }

    func restartDevSpace() async {
        guard let settings else {
            notice = configurationValidationMessage
            return
        }
        saveSettings()

        await perform("devspace-restart") {
            try await devspace.restart(settings: settings)
        }
    }

    func takeOverDevSpace() async {
        guard let settings else {
            notice = configurationValidationMessage
            return
        }
        saveSettings()

        await perform("devspace-takeover") {
            try await devspace.takeOver(settings: settings)
        }
    }

    func startAll() async {
        guard let settings else {
            notice = configurationValidationMessage
            return
        }
        saveSettings()

        await perform("start-all") {
            let current = await devspace.status(port: settings.port)
            if case .external = current.health {
                try await devspace.takeOver(settings: settings)
            } else {
                try await devspace.start(settings: settings)
            }
            try await tailscale.start(port: settings.port)
        }
    }

    func stopAll() async {
        guard let port else {
            notice = ManagerError.invalidPort.localizedDescription
            return
        }

        await perform("stop-all") {
            try await devspace.stop(port: port)
            try await tailscale.reset()
        }
    }

    private var configurationValidationMessage: String {
        if port == nil {
            return ManagerError.invalidPort.localizedDescription
        }
        return workingDirectoryValidationMessage ?? "请选择有效的 DevSpace 工作目录。"
    }

    private func perform(
        _ action: String,
        operation: () async throws -> Void
    ) async {
        guard busyAction == nil else { return }
        busyAction = action
        notice = nil

        do {
            try await operation()
            await refresh()
        } catch {
            notice = error.localizedDescription
            await refresh()
        }

        busyAction = nil
    }
}
