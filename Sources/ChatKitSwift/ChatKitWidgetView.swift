import SwiftUI

struct ChatKitWidgetView: View {
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    var body: some View {
        ChatKitWidgetNodeView(node: item.widget, item: item, session: session)
    }
}

private struct ChatKitWidgetNodeView: View {
    let node: ChatKitWidgetNode
    let item: ChatKitWidgetItem
    let session: ChatKitSession

    var body: some View {
        switch node.type {
        case "Basic", "Box", "Col", "Form":
            VStack(alignment: .leading, spacing: 10) {
                children
            }
        case "Row":
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                children
            }
        case "Card":
            VStack(alignment: .leading, spacing: 12) {
                children
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.tertiary)
            }
        case "ListView":
            VStack(alignment: .leading, spacing: 8) {
                children
            }
        case "ListViewItem":
            actionButtonOrContent {
                HStack {
                    children
                    Spacer()
                }
            }
        case "Title":
            Text(node.value ?? "")
                .font(.title3)
                .bold()
        case "Caption":
            Text(node.value ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case "Text":
            Text(node.value ?? "")
                .font(.body)
        case "Markdown":
            Text(node.value ?? "")
                .font(.body)
        case "Badge":
            Text(node.label ?? node.value ?? "")
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.tertiary)
                }
        case "Icon":
            Image(systemName: ChatKitStyle.systemImage(for: node.name ?? node.value ?? "sparkle"))
                .accessibilityHidden(true)
        case "Image":
            widgetImage
        case "Button":
            widgetButton
        case "Divider":
            Divider()
        case "Spacer":
            Spacer(minLength: 8)
        case "Input", "Textarea", "Select", "DatePicker", "Checkbox", "RadioGroup", "Label", "Table", "Table.Row", "Table.Cell", "Transition":
            VStack(alignment: .leading, spacing: 6) {
                Text(node.label ?? node.name ?? node.type)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                children
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text(node.type)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                children
            }
        }
    }

    private var children: some View {
        ForEach(node.children, id: \.stableID) { child in
            ChatKitWidgetNodeView(node: child, item: item, session: session)
        }
    }

    @ViewBuilder
    private var widgetImage: some View {
        if let source = node.source, let url = URL(string: source) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else if phase.error != nil {
                    Label("Image failed to load", systemImage: "exclamationmark.triangle")
                } else {
                    ProgressView()
                }
            }
            .accessibilityLabel(node.altText ?? "Image")
        }
    }

    @ViewBuilder
    private var widgetButton: some View {
        if node.raw["style"]?.stringValue == "primary" {
            Button(node.label ?? "Action", systemImage: ChatKitStyle.systemImage(for: node.raw["iconStart"]?.stringValue ?? "bolt")) {
                Task { await performActionIfPossible() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(node.isDisabled)
        } else {
            Button(node.label ?? "Action", systemImage: ChatKitStyle.systemImage(for: node.raw["iconStart"]?.stringValue ?? "bolt")) {
                Task { await performActionIfPossible() }
            }
            .buttonStyle(.bordered)
            .disabled(node.isDisabled)
        }
    }

    @ViewBuilder
    private func actionButtonOrContent(@ViewBuilder content: () -> some View) -> some View {
        if node.action != nil {
            Button(action: { Task { await performActionIfPossible() } }) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }

    private func performActionIfPossible() async {
        guard let action = node.action else {
            return
        }

        if let callback = session.options.widgets.onAction {
            try? await callback(action, item)
        } else {
            try? await session.sendCustomAction(action, itemID: item.id)
        }
    }
}
