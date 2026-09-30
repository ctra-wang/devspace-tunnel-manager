import SwiftUI

struct StatusBadge: View {
    let health: ServiceHealth

    private var color: Color {
        switch health {
        case .running:
            return .green
        case .external:
            return .orange
        case .stopped:
            return .secondary
        case .error:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(health.title)
                .font(.callout.weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("状态：\(health.title)")
    }
}

struct ServicePanel<Content: View, Actions: View>: View {
    let title: String
    let systemImage: String
    let health: ServiceHealth
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    init(
        title: String,
        systemImage: String,
        health: ServiceHealth,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.health = health
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                    StatusBadge(health: health)
                }

                content

                Divider()

                HStack(spacing: 8) {
                    actions
                }
            }
            .padding(4)
        }
    }
}

struct InfoLine: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}
