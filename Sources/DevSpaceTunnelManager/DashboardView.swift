import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var model: AppState
    @State private var showingResetConfirmation = false
    @State private var didOfferInitialDirectorySelection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                connectionBar

                HStack(alignment: .top, spacing: 16) {
                    tailscalePanel
                    devspacePanel
                }

                endpointPanel
                logPanel
                environmentPanel
            }
            .padding(22)
        }
        .frame(minWidth: 780, minHeight: 620)
        .task {
            await model.refresh()
            if !model.hasValidWorkingDirectory && !didOfferInitialDirectorySelection {
                didOfferInitialDirectorySelection = true
                chooseWorkingDirectory()
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await model.refresh()
            }
        }
        .alert(
            "操作结果",
            isPresented: Binding(
                get: { model.notice != nil },
                set: { if !$0 { model.notice = nil } }
            )
        ) {
            Button("好") { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
        .confirmationDialog(
            "Reset Tailscale Funnel？",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Funnel", role: .destructive) {
                Task { await model.resetTailscale() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该操作会执行 tailscale funnel reset，并清除当前 Funnel 配置。")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 46, height: 46)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("DevSpace Tunnel Manager")
                    .font(.title2.weight(.semibold))
                Text("统一守护本地 MCP 服务与 Tailscale Funnel")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(
                health: model.overallHealthy ? .running : .stopped
            )
        }
    }

    private var connectionBar: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本地端口")
                        .font(.callout.weight(.medium))
                    HStack(spacing: 8) {
                        TextField("7676", text: $model.portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .font(.system(.body, design: .monospaced))
                        Button("保存设置") {
                            model.saveSettings()
                        }
                        .disabled(model.port == nil || model.busyAction != nil)
                    }
                    if let message = model.portValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Divider()
                    .frame(height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text("一键控制")
                        .font(.callout.weight(.medium))
                    HStack(spacing: 8) {
                        Button {
                            Task { await model.startAll() }
                        } label: {
                            Label("启动全部", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.port == nil || model.busyAction != nil)

                        Button {
                            Task { await model.stopAll() }
                        } label: {
                            Label("停止全部", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.busyAction != nil)

                        Button {
                            Task { await model.refresh() }
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.busyAction != nil)
                    }
                }

                Spacer()

                if model.busyAction != nil {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 22)
                }
            }
            .padding(4)
        }
    }

    private var tailscalePanel: some View {
        ServicePanel(
            title: "Tailscale Funnel",
            systemImage: "network",
            health: model.funnelStatus.health
        ) {
            VStack(alignment: .leading, spacing: 9) {
                InfoLine(
                    label: "公网地址",
                    value: model.funnelStatus.publicURL ?? "尚未启用",
                    monospaced: true
                )
                InfoLine(
                    label: "代理目标",
                    value: model.funnelStatus.proxyTarget ?? "—",
                    monospaced: true
                )
                Text(model.funnelStatus.detail ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } actions: {
            Button("启动") {
                Task { await model.startTailscale() }
            }
            .disabled(model.port == nil || model.busyAction != nil)

            Button("停止") {
                showingResetConfirmation = true
            }
            .disabled(model.busyAction != nil)

            Button("Reset", role: .destructive) {
                showingResetConfirmation = true
            }
            .disabled(model.busyAction != nil)
        }
        .frame(maxWidth: .infinity)
    }

    private var devspacePanel: some View {
        ServicePanel(
            title: "DevSpace",
            systemImage: "terminal",
            health: model.devSpaceStatus.health
        ) {
            VStack(alignment: .leading, spacing: 9) {
                InfoLine(
                    label: "PID",
                    value: model.devSpaceStatus.pid.map(String.init) ?? "—",
                    monospaced: true
                )
                InfoLine(
                    label: "守护方式",
                    value: model.devSpaceStatus.isManaged ? "launchd / KeepAlive" : (model.devSpaceStatus.detail ?? "—")
                )
                Text(model.devSpaceStatus.command ?? model.devSpaceStatus.detail ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        } actions: {
            if case .external = model.devSpaceStatus.health {
                Button("接管并守护") {
                    Task { await model.takeOverDevSpace() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.busyAction != nil)
            } else {
                Button("启动") {
                    Task { await model.startDevSpace() }
                }
                .disabled(model.busyAction != nil)
            }

            Button("停止") {
                Task { await model.stopDevSpace() }
            }
            .disabled(model.busyAction != nil)

            Button("重启") {
                Task { await model.restartDevSpace() }
            }
            .disabled(model.port == nil || model.busyAction != nil)
        }
        .frame(maxWidth: .infinity)
    }

    private var endpointPanel: some View {
        GroupBox("MCP Endpoint") {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)

                Text(model.funnelStatus.mcpURL ?? "启动 Tailscale Funnel 后会显示公网 MCP 地址")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if let urlString = model.funnelStatus.mcpURL,
                   let url = URL(string: urlString) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(urlString, forType: .string)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }

                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("打开", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .padding(4)
        }
    }

    private var logPanel: some View {
        GroupBox("DevSpace 日志") {
            ScrollView {
                Text(model.logs)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(minHeight: 150, maxHeight: 230)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var environmentPanel: some View {
        GroupBox("运行设置") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Toggle(
                        "DevSpace 异常退出自动拉起",
                        isOn: Binding(
                            get: { model.autoRestart },
                            set: {
                                model.autoRestart = $0
                                model.saveSettings()
                            }
                        )
                    )

                    Toggle(
                        "登录后启动管理器",
                        isOn: Binding(
                            get: { model.launchAtLogin },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("工作目录")
                            .foregroundStyle(.secondary)
                        TextField("请选择 DevSpace 工作目录", text: $model.workingDirectory)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            chooseWorkingDirectory()
                        } label: {
                            Label("选择目录", systemImage: "folder")
                        }

                        Button("保存") {
                            model.saveSettings()
                        }
                        .disabled(
                            model.busyAction != nil
                                || model.port == nil
                                || !model.hasValidWorkingDirectory
                        )
                    }

                    if let message = model.workingDirectoryValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Divider()

                InfoLine(
                    label: "tailscale",
                    value: model.tailscalePath ?? "未找到",
                    monospaced: true
                )
                InfoLine(
                    label: "devspace",
                    value: model.devspacePath ?? "未找到",
                    monospaced: true
                )
            }
            .padding(4)
        }
    }

    private func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择 DevSpace 工作目录"
        panel.message = "请选择运行 devspace serve 时使用的项目目录。"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        if model.hasValidWorkingDirectory {
            panel.directoryURL = URL(fileURLWithPath: model.workingDirectory)
        }

        if panel.runModal() == .OK, let url = panel.url {
            model.setWorkingDirectory(url.path)
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var model: AppState

    var body: some View {
        StatusBadge(
            health: model.overallHealthy ? .running : .stopped
        )

        if let endpoint = model.funnelStatus.mcpURL {
            Text(endpoint)
        }

        Divider()

        Button("启动全部") {
            Task { await model.startAll() }
        }
        .disabled(model.port == nil || model.busyAction != nil)

        Button("重启 DevSpace") {
            Task { await model.restartDevSpace() }
        }
        .disabled(model.port == nil || model.busyAction != nil)

        Button("停止全部") {
            Task { await model.stopAll() }
        }
        .disabled(model.busyAction != nil)

        Divider()

        Button("打开管理窗口") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}
