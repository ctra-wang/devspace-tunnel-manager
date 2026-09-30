# DevSpace Tunnel Manager v0.1.1

macOS Apple Silicon（arm64）安全修复版本。

## 修复

- Tailscale Tunnel 改为 **TLS-terminated TCP** 转发
- DevSpace 恢复并保持默认的 `trust proxy=false`
- 不再向 LaunchAgent 写入 `DEVSPACE_TRUST_PROXY=1`
- 修复 HTTP reverse proxy 场景下的：
  - `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR`
  - `ERR_ERL_PERMISSIVE_TRUST_PROXY`
- Tailscale 状态解析新增 `TCPForward` / `TerminateTLS` 支持
- 保持对旧版 HTTP reverse proxy Tunnel 状态的读取兼容

## 工作方式

公网客户端仍然访问标准 HTTPS：

```text
https://<tailscale-host>/mcp
```

Tailscale 在 443 端口终止 TLS，然后以 TCP 转发到本地 DevSpace：

```bash
tailscale funnel --bg --yes \
  --tls-terminated-tcp=443 \
  tcp://127.0.0.1:<port>
```

由于这里是 TCP 层转发，Tailscale 不再向 HTTP 请求中注入 `X-Forwarded-For`，因此 DevSpace 不需要信任代理提供的客户端 IP 头。

## 其他功能

- 原生 SwiftUI macOS 菜单栏应用
- DevSpace `serve` 启动、停止、重启与 launchd 守护
- DevSpace 异常退出自动拉起
- 可配置本地端口与工作目录
- DevSpace Owner password 可视化管理
- Tailscale Tunnel 启动、状态检测与 Reset
- 公网 MCP Endpoint 展示、复制与打开
- DevSpace 日志查看
- 登录后自动启动管理器
- Apple Silicon 原生 arm64 构建
- macOS App Icon
- 简体中文 / English README

## 下载

`DevSpace-Tunnel-Manager-v0.1.1-macos-arm64.zip`

支持：

- macOS 13+
- Apple Silicon / arm64

## 校验

```bash
shasum -a 256 DevSpace-Tunnel-Manager-v0.1.1-macos-arm64.zip
```

并与 `SHA256SUMS.txt` 对比。

## macOS Gatekeeper

当前版本采用 ad-hoc 签名，尚未进行 Apple Developer ID 签名和 Notarization。

首次运行如被 Gatekeeper 阻止，请使用：

```text
右键应用 → 打开 → 打开
```
