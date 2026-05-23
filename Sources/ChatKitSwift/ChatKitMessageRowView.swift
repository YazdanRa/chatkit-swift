import SwiftUI

struct ChatKitMessageRowView: View {
    let item: ChatKitThreadItem
    let session: ChatKitSession

    var body: some View {
        switch item {
        case let .userMessage(message):
            messageBubble(alignment: .trailing, role: "You") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
                        Text(content.displayText)
                            .font(.body)
                    }
                }
            }
        case let .assistantMessage(message):
            messageBubble(alignment: .leading, role: "Assistant") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
                        Text(content.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    if session.options.threadItemActions.feedback || session.options.threadItemActions.retry {
                        ChatKitThreadItemActionsView(itemID: message.id, session: session)
                    }
                }
            }
        case let .widget(widget):
            messageBubble(alignment: .leading, role: "Widget") {
                ChatKitWidgetView(item: widget, session: session)
            }
        case let .clientToolCall(tool):
            messageBubble(alignment: .leading, role: "Client tool") {
                Label(tool.name, systemImage: tool.status == "completed" ? "checkmark.circle" : "wrench.and.screwdriver")
                    .font(.body)
            }
        case let .structuredInput(item):
            messageBubble(alignment: .leading, role: "Structured input") {
                ChatKitStructuredInputView(item: item, session: session)
            }
        case let .generatedImage(item):
            messageBubble(alignment: .leading, role: "Generated image") {
                if let image = item.image {
                    AsyncImage(url: image.url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Label("Image failed to load", systemImage: "exclamationmark.triangle")
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxHeight: 320)
                    .clipShape(.rect(cornerRadius: 8))
                    .accessibilityLabel("Generated image")
                }
            }
        case .task, .workflow, .endOfTurn, .hiddenContext, .sdkHiddenContext, .unknown:
            EmptyView()
        }
    }

    private func messageBubble<Content: View>(alignment: HorizontalAlignment, role: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if alignment == .trailing {
                Spacer(minLength: 40)
            }
            VStack(alignment: alignment, spacing: 6) {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                content()
                    .padding(12)
                    .background(alignment == .trailing ? .blue.opacity(0.16) : .secondary.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 12))
            }
            if alignment == .leading {
                Spacer(minLength: 40)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
