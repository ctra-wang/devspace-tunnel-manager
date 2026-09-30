import SwiftUI

@main
struct DevSpaceTunnelManagerApp: App {
    @StateObject private var model = AppState()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(model)
        }
        .defaultSize(width: 920, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("刷新状态") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(model)
                .task {
                    await model.refresh()
                }
        } label: {
            Label(
                "DevSpace Tunnel Manager",
                systemImage: model.overallHealthy
                    ? "point.3.connected.trianglepath.dotted"
                    : "network.slash"
            )
        }
    }
}
