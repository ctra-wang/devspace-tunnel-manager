# DevSpace Tunnel Manager

[简体中文](README.md) | [English](README.en.md)

<img width="920" height="923" alt="DevSpace Tunnel Manager" src="https://github.com/user-attachments/assets/5f993a21-f8a6-4383-aef1-fb1794aa0d26" />

一个原生 macOS 菜单栏应用，用于统一管理本地 **DevSpace MCP Server** 和 **Tailscale Tunnel**。

基于 SwiftUI 开发，当前主要支持 **Apple Silicon（M 系列芯片 / arm64）**。

## 功能

- Tailscale Tunnel 启动、状态检测与 Reset
- 使用 `tailscale funnel --bg` 后台运行
- `devspace serve` 启动、停止、重启
- 使用 macOS `launchd` 守护 DevSpace
- DevSpace 异常退出自动拉起
- 可视化配置本地端口
- 首次启动使用 macOS 原生目录选择器选择 DevSpace 工作目录
- 自动检测已有 `devspace serve` 并安全接管
- 自动显示公网 MCP Endpoint
- DevSpace stdout / stderr 日志查看
- Owner password 可视化管理
- 使用 Tailscale TLS-terminated TCP 转发，DevSpace 保持 `trust proxy=false`
- 菜单栏快捷控制
- 可选登录后自动启动
- 自动查找 Tailscale / DevSpace CLI
- 原生 macOS App Icon

## 系统要求

- macOS 13 或更高版本
- Apple Silicon（arm64）
- 已安装并登录 Tailscale
- 已安装 DevSpace CLI

应用会优先检查常见 CLI 路径，并在找不到时通过登录 Shell 的 `command -v` 自动探测。

## 首次启动

第一次启动时，应用会要求选择运行：

```bash
devspace serve
```

时使用的项目目录。

默认本地端口：

```text
7676
```

端口可以直接在界面中修改。

项目不会内置任何用户的个人绝对路径。

## DevSpace 守护

应用会创建用户级 LaunchAgent：

```text
~/Library/LaunchAgents/io.github.devspace-tunnel-manager.devspace.plist
```

并使用：

```text
PORT=<配置端口>
```

DevSpace 保持默认的 `trust proxy=false`。

启动：

```bash
devspace serve
```

启用自动拉起后，DevSpace 即使在管理器窗口关闭后也可以继续运行。

## Owner password

DevSpace OAuth 的 Owner password 可以直接在应用中设置。

DevSpace 1.0.8 对应的配置字段为：

```text
DEVSPACE_OAUTH_OWNER_TOKEN
```

管理器不会把密码写入 Git、UserDefaults 或 LaunchAgent plist，而是使用 DevSpace 自己的认证文件：

```text
~/.devspace/auth.json
```

文件权限保持为：

```text
600
```

Owner password 至少需要 16 个字符。修改后重启 DevSpace 生效。

## 已有进程接管

如果配置端口已经被其他进程占用，应用不会直接杀掉该进程。

只有检测到命令明确包含：

```text
devspace
serve
```

时才允许接管。

如果已有匹配同一端口的旧 LaunchAgent，应用会先卸载旧服务，再迁移到当前管理器。

## Tailscale Tunnel

启动：

```bash
tailscale funnel --bg --yes <port>
```

查看状态：

```bash
tailscale funnel status --json
```

Reset / 停止当前 Tunnel：

```bash
tailscale funnel reset
```

公网 MCP URL 会根据当前 Tunnel 状态中的 `TerminateTLS` / `TCPForward` 动态生成，不会写死在源码中。管理器仍兼容读取旧版 HTTP reverse proxy Tunnel 状态。

## 日志

DevSpace 日志保存在：

```text
~/Library/Logs/DevSpaceTunnelManager/devspace.stdout.log
~/Library/Logs/DevSpaceTunnelManager/devspace.stderr.log
```

应用内也可以查看最近日志。

## 从源码构建

```bash
git clone git@github.com:ctra-wang/devspace-tunnel-manager.git
cd devspace-tunnel-manager
zsh scripts/build-app.sh
```

生成：

```text
dist/DevSpace Tunnel Manager.app
```

启动：

```bash
open "dist/DevSpace Tunnel Manager.app"
```

构建脚本会自动：

1. 编译 arm64 Release
2. 生成 macOS App Icon
3. 生成标准 `.icns`
4. 创建 App Bundle
5. 进行 ad-hoc codesign

## GitHub Releases

建议 Release 附件命名：

```text
DevSpace-Tunnel-Manager-v0.1.0-macos-arm64.zip
```

当前本地构建使用 ad-hoc 签名，尚未进行 Apple Developer ID 签名与 Notarization。

因此从 GitHub 下载后，首次启动时 macOS Gatekeeper 可能要求：

```text
右键应用 → 打开 → 打开
```

## 隐私

DevSpace Tunnel Manager 是本地运行的开发者工具。

公开仓库不会内置：

- API Key
- Access Token
- Tailscale Auth Key
- Owner password
- Webhook Key
- 用户绝对路径
- 私人服务器地址
- 个人 Tailscale 域名

应用不包含分析或遥测功能。

## License

本项目使用 [MIT License](LICENSE)。

Copyright © 2026 DevSpace Tunnel Manager contributors
