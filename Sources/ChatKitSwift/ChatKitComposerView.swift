import SwiftUI

struct ChatKitComposerView: View {
    @Bindable var session: ChatKitSession
    @FocusState private var isFocused: Bool
    @State private var entityQuery = ""
    @State private var entities: [ChatKitEntity] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !session.composer.attachments.isEmpty {
                ChatKitAttachmentStripView(attachments: session.composer.attachments)
            }

            if !entities.isEmpty {
                ChatKitEntitySuggestionsView(entities: entities, session: session)
            }

            HStack(alignment: .bottom, spacing: 8) {
                if session.options.entities.showComposerMenu, session.options.entities.onTagSearch != nil {
                    Button("Mention", systemImage: "at") {
                        entityQuery = "@"
                        Task { await searchEntities(query: "") }
                    }
                    .buttonStyle(.borderless)
                }

                Menu("Tools", systemImage: "wrench.and.screwdriver") {
                    Button("No tool") {
                        Task { await session.setComposerValue(selectedToolID: nil) }
                    }
                    ForEach(session.options.composer.tools) { tool in
                        Button(tool.label, systemImage: ChatKitStyle.systemImage(for: tool.icon)) {
                            Task {
                                await session.setComposerValue(
                                    text: tool.placeholderOverride ?? session.composer.text,
                                    selectedToolID: tool.id
                                )
                            }
                        }
                    }
                }
                .disabled(session.options.composer.tools.isEmpty)

                Menu("Models", systemImage: "cpu") {
                    ForEach(session.options.composer.models) { model in
                        Button(model.label) {
                            Task { await session.setComposerValue(selectedModelID: model.id) }
                        }
                        .disabled(model.disabled)
                    }
                }
                .disabled(session.options.composer.models.isEmpty)

                TextField(session.options.composer.placeholder, text: $session.composer.text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onChange(of: session.composer.text) {
                        updateEntityQuery(from: session.composer.text)
                    }
                    .onChange(of: session.composerFocusRequestID) {
                        isFocused = true
                    }
                    .task(id: entityQuery) {
                        await searchEntities(query: entityQuery)
                    }

                Button("Send", systemImage: "paperplane.fill", action: send)
                    .buttonStyle(.borderedProminent)
                    .disabled(session.composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && session.composer.content.isEmpty)
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func send() {
        let text = session.composer.text
        let content = session.composer.content.isEmpty ? nil : session.composer.content
        let attachments = session.composer.attachments
        let reply = session.composer.reply

        Task {
            try? await session.sendUserMessage(
                text: text,
                content: content,
                reply: reply,
                attachments: attachments
            )
        }
    }

    private func updateEntityQuery(from text: String) {
        guard let atIndex = text.lastIndex(of: "@") else {
            entityQuery = ""
            entities = []
            return
        }

        let query = String(text[text.index(after: atIndex)...])
        entityQuery = query
    }

    private func searchEntities(query: String) async {
        guard let search = session.options.entities.onTagSearch else {
            entities = []
            return
        }

        do {
            entities = try await search(query)
        } catch where !Task.isCancelled {
            entities = []
        } catch {}
    }
}
