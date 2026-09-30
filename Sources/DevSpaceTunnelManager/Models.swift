import Foundation

enum ServiceHealth: Equatable {
    case running
    case stopped
    case external
    case error(String)

    var title: String {
        switch self {
        case .running:
            return "运行中"
        case .stopped:
            return "已停止"
        case .external:
            return "外部运行"
        case .error:
            return "异常"
        }
    }
}

struct FunnelStatus: Equatable {
    var health: ServiceHealth = .stopped
    var publicURL: String?
    var proxyTarget: String?
    var detail: String?

    var mcpURL: String? {
        guard let publicURL else { return nil }
        return publicURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/mcp"
    }
}

struct DevSpaceStatus: Equatable {
    var health: ServiceHealth = .stopped
    var pid: Int?
    var command: String?
    var detail: String?
    var isManaged = false
}

struct AppSettings: Equatable {
    var port: Int
    var workingDirectory: String
    var autoRestart: Bool
}

enum ManagerError: LocalizedError {
    case commandNotFound(String)
    case invalidPort
    case invalidOwnerPassword
    case commandFailed(String)
    case portOccupied(pid: Int, command: String?)
    case unsafeExternalProcess(pid: Int, command: String?)

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            return "找不到命令：\(command)。请确认已经安装，并且终端可以正常执行。"
        case .invalidPort:
            return "端口必须是 1 到 65535 之间的数字。"
        case .invalidOwnerPassword:
            return "Owner password 至少需要 16 个字符。"
        case .commandFailed(let message):
            return message
        case .portOccupied(let pid, let command):
            let suffix = command.map { "（\($0)）" } ?? ""
            return "端口已被 PID \(pid) 占用\(suffix)。如果这是 DevSpace，请使用“接管并守护”。"
        case .unsafeExternalProcess(let pid, let command):
            let suffix = command.map { "：\($0)" } ?? ""
            return "拒绝停止 PID \(pid)\(suffix)。只会接管明确匹配 devspace serve 的进程。"
        }
    }
}
