# DevSpace Tunnel Manager

[简体中文](README.md) | [English](README.en.md)

<img width="920" height="923" alt="DevSpace Tunnel Manager" src="https://github.com/user-attachments/assets/5f993a21-f8a6-4383-aef1-fb1794aa0d26" />

A native macOS menu bar application for managing a local **DevSpace MCP Server** together with **Tailscale Funnel**.

Built with SwiftUI and designed primarily for **Apple Silicon Macs (arm64)**.

## Features

- Start, inspect, and reset Tailscale Funnel
- Run Funnel in the background with `tailscale funnel --bg`
- Start, stop, and restart `devspace serve`
- Supervise DevSpace using macOS `launchd`
- Automatically restart DevSpace after an unexpected exit
- Configure the local service port
- Choose the DevSpace working directory with the native macOS folder picker
- Detect and safely take over an existing `devspace serve` process
- Show the current public MCP endpoint
- View DevSpace stdout / stderr logs
- Manage the DevSpace Owner password from the UI
- Configure reverse-proxy trust with `DEVSPACE_TRUST_PROXY=1`
- Control services from the menu bar
- Optionally launch the manager at login
- Automatically locate Tailscale and DevSpace CLIs
- Native macOS App Icon

## Requirements

- macOS 13 or later
- Apple Silicon (arm64)
- Tailscale installed and signed in
- DevSpace CLI installed

The app checks common CLI locations first and falls back to the user's login shell with `command -v`.

## First Launch

On first launch, choose the project directory where:

```bash
devspace serve
```

should run.

The default local port is:

```text
7676
```

and can be changed from the UI.

No personal filesystem path is embedded in the project.

## DevSpace Supervision

The app creates a user LaunchAgent:

```text
~/Library/LaunchAgents/io.github.devspace-tunnel-manager.devspace.plist
```

with:

```text
PORT=<configured-port>
DEVSPACE_TRUST_PROXY=1
```

and runs:

```bash
devspace serve
```

When automatic restart is enabled, DevSpace can keep running even after the manager window is closed.

## Owner Password

The DevSpace OAuth Owner password can be configured directly from the application.

DevSpace 1.0.8 uses:

```text
DEVSPACE_OAUTH_OWNER_TOKEN
```

The manager does not store the password in Git, UserDefaults, or the LaunchAgent plist. It uses DevSpace's own authentication file:

```text
~/.devspace/auth.json
```

with file permissions kept at:

```text
600
```

The Owner password must contain at least 16 characters. Restart DevSpace after changing it.

## Existing Process Takeover

If the configured port is already occupied, the app does not blindly terminate the process.

Takeover is allowed only when the detected command clearly contains:

```text
devspace
serve
```

If an older LaunchAgent manages the same port, the app unloads it before migrating the service to the current manager.

## Tailscale Funnel

Start:

```bash
tailscale funnel --bg --yes <port>
```

Inspect:

```bash
tailscale funnel status --json
```

Reset / stop the current Funnel:

```bash
tailscale funnel reset
```

The public MCP URL is derived dynamically from the current Funnel configuration and is never hard-coded.

## Logs

DevSpace logs are stored at:

```text
~/Library/Logs/DevSpaceTunnelManager/devspace.stdout.log
~/Library/Logs/DevSpaceTunnelManager/devspace.stderr.log
```

Recent logs are also available directly in the app.

## Build From Source

```bash
git clone git@github.com:ctra-wang/devspace-tunnel-manager.git
cd devspace-tunnel-manager
zsh scripts/build-app.sh
```

The generated app is placed at:

```text
dist/DevSpace Tunnel Manager.app
```

Launch it with:

```bash
open "dist/DevSpace Tunnel Manager.app"
```

The build script automatically:

1. Builds an arm64 release binary
2. Generates the macOS app artwork
3. Produces a standard `.icns`
4. Creates the App Bundle
5. Applies ad-hoc code signing

## GitHub Releases

Recommended release asset name:

```text
DevSpace-Tunnel-Manager-v0.1.0-macos-arm64.zip
```

Current local builds are ad-hoc signed and are not yet signed with an Apple Developer ID or notarized by Apple.

Gatekeeper may therefore require the first launch to use:

```text
Right-click the app → Open → Open
```

## Privacy

DevSpace Tunnel Manager is a local developer utility.

The public repository does not embed:

- API keys
- Access tokens
- Tailscale auth keys
- Owner passwords
- Webhook keys
- Personal filesystem paths
- Private server addresses
- Personal Tailscale hostnames

The app does not include analytics or telemetry.

## License

Licensed under the [MIT License](LICENSE).

Copyright © 2026 DevSpace Tunnel Manager contributors
