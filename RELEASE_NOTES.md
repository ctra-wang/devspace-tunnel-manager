# DevSpace Tunnel Manager v0.1.0

首个公开版本，面向 macOS Apple Silicon（arm64）。

## 主要功能

- 原生 SwiftUI macOS 菜单栏应用
- DevSpace `serve` 启动、停止、重启与 launchd 守护
- DevSpace 异常退出自动拉起
- 可配置本地端口与工作目录
- DevSpace Owner password 可视化管理
- 使用 Tailscale TLS-terminated TCP，DevSpace 保持 `trust proxy=false`
- Tailscale Tunnel 启动、状态检测与 Reset
- 修复 `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` / `ERR_ERL_PERMISSIVE_TRUST_PROXY` 代理校验冲突
- 公网 MCP Endpoint 展示、复制与打开
- DevSpace 日志查看
- 登录后自动启动管理器
- Apple Silicon 原生 arm64 构建
- macOS App Icon
- 简体中文 / English README

## 下载

下载：

`DevSpace-Tunnel-Manager-v0.1.0-macos-arm64.zip`

支持：

- macOS 13+
- Apple Silicon / arm64

## 校验

下载后可使用：

```bash
shasum -a 256 DevSpace-Tunnel-Manager-v0.1.0-macos-arm64.zip
```

并与 `SHA256SUMS.txt` 对比。

## macOS Gatekeeper

当前版本采用 ad-hoc 签名，尚未进行 Apple Developer ID 签名和 Notarization。

首次运行如被 Gatekeeper 阻止，请使用：

```text
右键应用 → 打开 → 打开
```
