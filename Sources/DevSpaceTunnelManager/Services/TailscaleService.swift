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
                return FunnelStatus(health: .stopped, detail: "尚未配置 Tunnel")
            }

            let data = Data(result.stdout.utf8)
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return FunnelStatus(
                    health: .error("无法解析 Tailscale Tunnel 状态"),
                    detail: "tailscale funnel status --json 返回了无效 JSON"
                )
            }

            if let tcpStatus = tlsTerminatedTCPStatus(from: root) {
                return tcpStatus
            }

            if let webStatus = legacyWebProxyStatus(from: root) {
                return webStatus
            }

            return FunnelStatus(
                health: .stopped,
                detail: "尚未发现可用的 Tunnel 转发"
            )
        } catch {
            return FunnelStatus(
                health: .error(error.localizedDescription),
                detail: error.localizedDescription
            )
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
            arguments: [
                "funnel",
                "--bg",
                "--yes",
                "--tls-terminated-tcp=443",
                "tcp://127.0.0.1:\(port)"
            ]
        )

        guard result.exitCode == 0 else {
            throw ManagerError.commandFailed(
                result.combinedOutput.isEmpty
                    ? "启动 Tailscale Tunnel 失败。"
                    : result.combinedOutput
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
                result.combinedOutput.isEmpty
                    ? "Reset Tailscale Tunnel 失败。"
                    : result.combinedOutput
            )
        }
    }

    private func tlsTerminatedTCPStatus(from root: [String: Any]) -> FunnelStatus? {
        guard let tcp = root["TCP"] as? [String: Any] else {
            return nil
        }

        let sortedPorts = tcp.keys.sorted {
            (Int($0) ?? Int.max) < (Int($1) ?? Int.max)
        }

        for port in sortedPorts {
            guard
                let rawHandler = tcp[port] as? [String: Any],
                let target = rawHandler["TCPForward"] as? String,
                !target.isEmpty,
                let terminateTLS = rawHandler["TerminateTLS"] as? String,
                !terminateTLS.isEmpty
            else {
                continue
            }

            let publicHost = normalizedPublicHost(terminateTLS)
            return FunnelStatus(
                health: .running,
                publicURL: "https://\(publicHost)",
                proxyTarget: "tcp://\(target)",
                detail: "Tunnel 使用 TLS-terminated TCP 安全转发"
            )
        }

        return nil
    }

    private func legacyWebProxyStatus(from root: [String: Any]) -> FunnelStatus? {
        guard
            let web = root["Web"] as? [String: Any],
            !web.isEmpty
        else {
            return nil
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
                    detail: "检测到旧版 HTTP reverse proxy Tunnel"
                )
            }
        }

        return nil
    }

    private func normalizedPublicHost(_ hostAndPort: String) -> String {
        if hostAndPort.hasSuffix(":443") {
            return String(hostAndPort.dropLast(4))
        }
        return hostAndPort
    }
}
