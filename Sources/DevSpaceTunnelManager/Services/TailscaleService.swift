import Foundation

struct TailscaleService {
    private let candidates = [
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    ]

    func executablePath() async -> String? {
        await CommandLocator.shared.resolve("tailscale", candidates: candidates)
    }

    func status() async -> FunnelStatus {
        guard let path = await executablePath() else {
            return FunnelStatus(
                health: .error("tailscale 未安装"),
                detail: "找不到 tailscale 命令"
            )
        }

        do {
            let result = try await CommandRunner.shared.run(
                executable: path,
                arguments: ["funnel", "status", "--json"]
            )

            guard result.exitCode == 0 else {
                return FunnelStatus(
                    health: .error(result.combinedOutput),
                    detail: result.combinedOutput
                )
            }

            guard !result.stdout.isEmpty else {
                return FunnelStatus(health: .stopped, detail: "尚未配置 Funnel")
            }

            let data = Data(result.stdout.utf8)
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let web = root["Web"] as? [String: Any],
                !web.isEmpty
            else {
                return FunnelStatus(health: .stopped, detail: "尚未配置 Funnel")
            }

            for (hostAndPort, rawValue) in web {
                guard
                    let value = rawValue as? [String: Any],
                    let handlers = value["Handlers"] as? [String: Any]
                else {
                    continue
                }

                for (_, rawHandler) in handlers {
                    guard
                        let handler = rawHandler as? [String: Any],
                        let proxy = handler["Proxy"] as? String
                    else {
                        continue
                    }

                    let publicHost = normalizedPublicHost(hostAndPort)
                    return FunnelStatus(
                        health: .running,
                        publicURL: "https://\(publicHost)",
                        proxyTarget: proxy,
                        detail: "Funnel 正在后台转发"
                    )
                }
            }

            return FunnelStatus(health: .stopped, detail: "尚未发现可用的 Funnel 代理")
        } catch {
            return FunnelStatus(health: .error(error.localizedDescription), detail: error.localizedDescription)
        }
    }

    func start(port: Int) async throws {
        guard (1...65535).contains(port) else {
            throw ManagerError.invalidPort
        }
        guard let path = await executablePath() else {
            throw ManagerError.commandNotFound("tailscale")
        }

        let result = try await CommandRunner.shared.run(
            executable: path,
            arguments: ["funnel", "--bg", "--yes", String(port)]
        )

        guard result.exitCode == 0 else {
            throw ManagerError.commandFailed(
                result.combinedOutput.isEmpty ? "启动 Tailscale Funnel 失败。" : result.combinedOutput
            )
        }
    }

    func reset() async throws {
        guard let path = await executablePath() else {
            throw ManagerError.commandNotFound("tailscale")
        }

        let result = try await CommandRunner.shared.run(
            executable: path,
            arguments: ["funnel", "reset"]
        )

        guard result.exitCode == 0 else {
            throw ManagerError.commandFailed(
                result.combinedOutput.isEmpty ? "Reset Tailscale Funnel 失败。" : result.combinedOutput
            )
        }
    }

    private func normalizedPublicHost(_ hostAndPort: String) -> String {
        if hostAndPort.hasSuffix(":443") {
            return String(hostAndPort.dropLast(4))
        }
        return hostAndPort
    }
}
