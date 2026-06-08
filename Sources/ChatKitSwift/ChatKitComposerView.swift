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

            controls

            if let disclaimer = session.options.disclaimer {
                ChatKitDisclaimerView(disclaimer: disclaimer)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.clear)
    }

    @ViewBuilder
    private var controls: some View {
        #if os(iOS)
            if session.options.glassEffect {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 16) {
                        controlsContent
                    }
                } else {
                    controlsContent
                }
            } else {
                controlsContent
            }
        #else
            controlsContent
        #endif
    }

    private var controlsContent: some View {
        HStack(alignment: .bottom, spacing: 16) {
            if ChatKitComposerControls.showsAttachmentButton(for: session.options) {
                Button("Add attachment", systemImage: "plus", action: requestAttachment)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .chatKitComposerCircleBackground(
                        glassEffect: session.options.glassEffect,
                        isInteractive: canRequestAttachment,
                    )
                    .disabled(!canRequestAttachment)
            }

            ZStack(alignment: .bottomTrailing) {
                TextField(session.options.composer.placeholder, text: $session.composer.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1 ... 6)
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
                    .foregroundStyle(sendButtonForegroundStyle)
                    .frame(width: 34, height: 34)
                    .chatKitComposerSendBackground(glassEffect: session.options.glassEffect, isInteractive: canSend)
                    .opacity(canSend ? 1 : 0.35)
                    .disabled(!canSend)
                    .padding(.trailing, 4)
                    .padding(.bottom, 5)
            }
            .frame(minHeight: 44)
            .chatKitComposerInputBackground(glassEffect: session.options.glassEffect)
        }
    }

    private var canSend: Bool {
        !session.composer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !session.composer.content.isEmpty ||
            !session.composer.attachments.isEmpty
    }

    private var sendButtonForegroundStyle: Color {
        canSend ? .white : .secondary
    }

    private var canRequestAttachment: Bool {
        guard let attachments = session.options.composer.attachments else {
            return false
        }
        return attachments.onRequest != nil &&
            session.composer.attachments.count + session.composer.files.count < attachments.maxCount
    }

    private func requestAttachment() {
        session.options.composer.attachments?.onRequest?()
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
                attachments: attachments,
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

private extension View {
    @ViewBuilder
    func chatKitComposerCircleBackground(glassEffect: Bool, isInteractive: Bool) -> some View {
        #if os(iOS)
            if glassEffect, #available(iOS 26.0, *) {
                self.glassEffect(.regular.interactive(isInteractive), in: Circle())
            } else {
                background(.regularMaterial, in: Circle())
            }
        #else
            background(.regularMaterial, in: Circle())
        #endif
    }

    @ViewBuilder
    func chatKitComposerInputBackground(glassEffect: Bool) -> some View {
        #if os(iOS)
            if glassEffect, #available(iOS 26.0, *) {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            } else {
                chatKitComposerMaterialInputBackground()
            }
        #else
            chatKitComposerMaterialInputBackground()
        #endif
    }

    @ViewBuilder
    func chatKitComposerSendBackground(glassEffect: Bool, isInteractive: Bool) -> some View {
        #if os(iOS)
            if glassEffect, #available(iOS 26.0, *) {
                if isInteractive {
                    background(Color.accentColor, in: Circle())
                        .glassEffect(
                            .regular
                                .tint(Color.accentColor.opacity(0.6))
                                .interactive(),
                            in: Circle(),
                        )
                        .shadow(color: Color.accentColor.opacity(0.28), radius: 10, y: 3)
                } else {
                    self.glassEffect(
                        .regular
                            .tint(Color.secondary.opacity(0.12)),
                        in: Circle(),
                    )
                }
            } else {
                background(Color.accentColor, in: Circle())
            }
        #else
            background(Color.accentColor, in: Circle())
        #endif
    }

    private func chatKitComposerMaterialInputBackground() -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.tertiary)
            }
    }
}
