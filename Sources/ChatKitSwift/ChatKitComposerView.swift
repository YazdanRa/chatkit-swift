import SwiftUI

struct ChatKitComposerView: View {
    @Bindable var session: ChatKitSession
    @FocusState private var isFocused: Bool
    @State private var entityQuery = ""
    @State private var entities: [ChatKitEntity] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !session.composer.attachments.isEmpty {
                ChatKitAttachmentStripView(attachments: session.composer.attachments)
            }

            if !entities.isEmpty {
                ChatKitEntitySuggestionsView(entities: entities, session: session)
            }

            HStack(alignment: .bottom, spacing: 16) {
                if hasComposerOptions {
                    Menu("Composer options", systemImage: "plus") {
                        if session.options.entities.showComposerMenu, session.options.entities.onTagSearch != nil {
                            Button("Mention", systemImage: "at") {
                                entityQuery = "@"
                                Task { await searchEntities(query: "") }
                            }
                        }

                        if !session.options.composer.tools.isEmpty {
                            Section("Tools") {
                                Button("No tool", systemImage: "xmark.circle") {
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
                        }

                        if !session.options.composer.models.isEmpty {
                            Section("Models") {
                                ForEach(session.options.composer.models) { model in
                                    if model.id == session.composer.selectedModelID {
                                        Button(model.label, systemImage: "checkmark") {
                                            Task { await session.setComposerValue(selectedModelID: model.id) }
                                        }
                                        .disabled(model.disabled)
                                    } else {
                                        Button(model.label) {
                                            Task { await session.setComposerValue(selectedModelID: model.id) }
                                        }
                                        .disabled(model.disabled)
                                    }
                                }
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
                }

                ZStack(alignment: .bottomTrailing) {
                    TextField(session.options.composer.placeholder, text: $session.composer.text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .frame(minHeight: 24, alignment: .center)
                        .padding(.leading, 16)
                        .padding(.trailing, 42)
                        .padding(.vertical, 10)
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

                    Button("Send", systemImage: "arrow.up", action: send)
                        .buttonStyle(.plain)
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .bold()
                        .foregroundStyle(Color.black)
                        .frame(width: 30, height: 30)
                        .background(Color.white, in: Circle())
                        .opacity(canSend ? 1 : 0.35)
                        .disabled(!canSend)
                        .padding(.trailing, 5)
                        .padding(.bottom, 7)
                }
                .frame(minHeight: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.tertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.clear)
    }

    private var hasComposerOptions: Bool {
        !session.options.composer.tools.isEmpty ||
            !session.options.composer.models.isEmpty ||
            (session.options.entities.showComposerMenu && session.options.entities.onTagSearch != nil)
    }

    private var canSend: Bool {
        !session.composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.composer.content.isEmpty
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
