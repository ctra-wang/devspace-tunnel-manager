# DevSpace Tunnel Manager

A native macOS menu bar app for managing a local [DevSpace](https://github.com/Waishnav/devspace) MCP server together with Tailscale Funnel.

Built with SwiftUI for Apple Silicon Macs.

## Features

- Start and inspect Tailscale Funnel with `--bg`
- Reset/stop the current Funnel configuration
- Run `devspace serve` under macOS `launchd`
- Automatically restart DevSpace after an unexpected exit
- Detect an existing external `devspace serve` process and safely take it over
- Configure the local service port
- Choose the DevSpace working directory with the native macOS folder picker
- Show the detected public MCP URL
- View DevSpace stdout/stderr logs
- Control services from the menu bar
- Optionally launch the manager at login
- Automatically locate common Tailscale and DevSpace CLI installations

## Requirements

- macOS 13 or later
- Apple Silicon (arm64)
- Tailscale installed and signed in
- DevSpace CLI installed

The app checks common CLI locations first and falls back to the user's login shell with `command -v`.

## First launch

On first launch, choose the directory where `devspace serve` should run.

The app does **not** ship with or assume any personal filesystem path. The selected directory is stored locally in macOS user defaults.

The default local port is `7676`, and it can be changed in the UI.

## Build from source

Only the Apple command line developer tools are required:

```bash
git clone https://github.com/ctra-wang/devspace-tunnel-manager.git
cd devspace-tunnel-manager
zsh scripts/build-app.sh
```

The generated app is placed at:

```text
dist/DevSpace Tunnel Manager.app
```

Open it with:

```bash
open "dist/DevSpace Tunnel Manager.app"
```

## DevSpace supervision

The app creates a user LaunchAgent:

```text
~/Library/LaunchAgents/io.github.devspace-tunnel-manager.devspace.plist
```

Logs are written to:

```text
~/Library/Logs/DevSpaceTunnelManager/devspace.stdout.log
~/Library/Logs/DevSpaceTunnelManager/devspace.stderr.log
```

The generated LaunchAgent explicitly configures `HOME`, `PATH`, and `PORT` so that DevSpace can find Homebrew/Node dependencies even when launched outside an interactive shell.

## Existing DevSpace process takeover

If the configured port is already occupied, the app does not blindly terminate the process.

The **Take Over & Supervise** action only sends `SIGTERM` when the detected process command line clearly contains both `devspace` and `serve`. It then waits for the port to become free before starting the launchd-managed instance.

Other processes are left untouched.

## Tailscale Funnel

Start:

```bash
tailscale funnel --bg --yes <port>
```

Inspect:

```bash
tailscale funnel status --json
```

Reset/stop the current Funnel configuration:

```bash
tailscale funnel reset
```

Tailscale currently exposes Funnel reset rather than a separate Funnel-specific stop command, so the app uses `reset` when stopping Funnel.

## Privacy

DevSpace Tunnel Manager is a local utility. It does not include analytics, telemetry, API keys, account credentials, or hard-coded public endpoints.

Tailscale and DevSpace authentication remain owned by their respective installed CLIs.

## License

MIT
