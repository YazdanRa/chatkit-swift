import SwiftUI

struct ChatKitThreadItemActionsView: View {
    let itemID: String
    let session: ChatKitSession

    var body: some View {
        HStack(spacing: 8) {
            if session.options.threadItemActions.feedback {
                Button("Good response", systemImage: "hand.thumbsup") {
                    Task { try? await session.addFeedback(itemIDs: [itemID], kind: .positive) }
                }
                Button("Bad response", systemImage: "hand.thumbsdown") {
                    Task { try? await session.addFeedback(itemIDs: [itemID], kind: .negative) }
                }
            }

            if session.options.threadItemActions.retry {
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { try? await session.retry(after: itemID) }
                }
            }
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .font(.body)
        .controlSize(.regular)
    }
}

struct ChatKitStructuredInputView: View {
    let item: ChatKitStructuredInputItem
    let session: ChatKitSession
    @State private var answers: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(item.inputs) { input in
                VStack(alignment: .leading, spacing: 6) {
                    Text(input.question)
                        .font(.body)
                    if let description = input.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let options = input.options, !options.isEmpty {
                        Picker(input.question, selection: binding(for: input.id)) {
                            ForEach(options, id: \.value) { option in
                                Text(option.value).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        TextField("Answer", text: binding(for: input.id), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Button("Submit", systemImage: "checkmark") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id, default: ""] },
            set: { answers[id] = $0 }
        )
    }

    private func submit() async {
        let payload = ChatKitStructuredInputSubmission(
            answers: answers.mapValues { .init(values: [$0]) }
        )
        try? await session.submitStructuredInput(payload, itemID: item.id)
    }
}

struct ChatKitProgressView: View {
    let progress: ChatKitEvent.ProgressUpdate

    var body: some View {
        Label(progress.text, systemImage: ChatKitStyle.systemImage(for: progress.icon ?? "sparkle"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}

struct ChatKitWaitingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Waiting for response")
                .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Waiting for response")
    }
}

struct ChatKitErrorView: View {
    let error: ChatKitEvent.ErrorEvent

    var body: some View {
        Label(error.message ?? "Something went wrong", systemImage: "exclamationmark.triangle")
            .font(.body)
            .foregroundStyle(.red)
            .padding(12)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 620, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(error.message ?? "Something went wrong")
    }
}

struct ChatKitDisclaimerView: View {
    let disclaimer: ChatKitOptions.Disclaimer

    var body: some View {
        Text(disclaimer.text)
            .font(.caption)
            .foregroundStyle(disclaimer.highContrast ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}

struct ChatKitAttachmentStripView: View {
    let attachments: [ChatKitAttachment]

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(attachments) { attachment in
                    Label(label(for: attachment), systemImage: icon(for: attachment))
                        .font(.caption)
                        .padding(8)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    private func label(for attachment: ChatKitAttachment) -> String {
        switch attachment {
        case let .file(file):
            file.name
        case let .image(image):
            image.name
        case let .unknown(_, type, _):
            type
        }
    }

    private func icon(for attachment: ChatKitAttachment) -> String {
        if case .image = attachment {
            "photo"
        } else {
            "paperclip"
        }
    }
}

struct ChatKitEntitySuggestionsView: View {
    let entities: [ChatKitEntity]
    let session: ChatKitSession

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(entities) { entity in
                    ChatKitEntitySuggestionButton(entity: entity, session: session)
                }
            }
        }
    }
}

private struct ChatKitEntitySuggestionButton: View {
    let entity: ChatKitEntity
    let session: ChatKitSession
    @State private var preview: ChatKitWidgetNode?

    var body: some View {
        Button(entity.title, systemImage: ChatKitStyle.systemImage(for: entity.icon ?? "tag")) {
            session.options.entities.onClick?(entity)
            Task {
                await session.setComposerValue(
                    content: session.composer.content + [.inputTag(.init(
                        text: entity.title,
                        id: entity.id,
                        group: entity.group,
                        data: entity.data.mapValues(JSONValue.string),
                        interactive: entity.interactive
                    ))]
                )
            }
        }
        .buttonStyle(.bordered)
        .popover(item: previewBinding) { preview in
            ChatKitWidgetNodePreview(node: preview)
                .padding()
        }
        .task {
            guard entity.interactive == true,
                  let requestPreview = session.options.entities.onRequestPreview,
                  preview == nil else {
                return
            }
            preview = try? await requestPreview(entity)
        }
    }

    private var previewBinding: Binding<ChatKitWidgetNode?> {
        Binding(
            get: { preview },
            set: { preview = $0 }
        )
    }
}

private struct ChatKitWidgetNodePreview: View {
    let node: ChatKitWidgetNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.value ?? node.label ?? node.type)
                .font(.body)
            ForEach(node.children, id: \.stableID) { child in
                ChatKitWidgetNodePreview(node: child)
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
    }
}
