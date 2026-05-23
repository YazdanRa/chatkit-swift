import SwiftUI

struct ChatKitMessageRowView: View {
    let item: ChatKitThreadItem
    let session: ChatKitSession

    var body: some View {
        switch item {
        case let .userMessage(message):
            messageBubble(alignment: .trailing) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
                        Text(content.displayText)
                            .font(.body)
                    }
                }
            }
        case let .assistantMessage(message):
            plainMessage {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(message.content.enumerated()), id: \.offset) { _, content in
                        ChatKitAssistantResponseTextView(markdown: content.text)
                    }

                    if session.options.threadItemActions.feedback || session.options.threadItemActions.retry {
                        ChatKitThreadItemActionsView(itemID: message.id, session: session)
                    }
                }
            }
        case let .widget(widget):
            plainMessage {
                ChatKitWidgetView(item: widget, session: session)
            }
        case let .clientToolCall(tool):
            plainMessage {
                Label(tool.name, systemImage: tool.status == "completed" ? "checkmark.circle" : "wrench.and.screwdriver")
                    .font(.body)
            }
        case let .structuredInput(item):
            plainMessage {
                ChatKitStructuredInputView(item: item, session: session)
            }
        case let .generatedImage(item):
            plainMessage {
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

    private func messageBubble<Content: View>(alignment: HorizontalAlignment, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if alignment == .trailing {
                Spacer(minLength: 56)
            }
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(bubbleStyle(for: alignment))
                }
                .overlay {
                    if alignment == .leading {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.tertiary)
                    }
                }
                .frame(maxWidth: 620, alignment: alignment == .trailing ? .trailing : .leading)
            if alignment == .leading {
                Spacer(minLength: 56)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func plainMessage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
        .frame(maxWidth: 620, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func bubbleStyle(for alignment: HorizontalAlignment) -> AnyShapeStyle {
        alignment == .trailing
            ? AnyShapeStyle(Color.accentColor.opacity(0.14))
            : AnyShapeStyle(.regularMaterial)
    }
}
