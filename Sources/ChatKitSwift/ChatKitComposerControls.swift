import SwiftUI

enum ChatKitComposerControls {
    static func showsAttachmentButton(for options: ChatKitOptions) -> Bool {
        options.composer.attachments?.enabled == true
    }

    static func showsOptionsMenu(for options: ChatKitOptions) -> Bool {
        !options.composer.tools.isEmpty ||
            !options.composer.models.isEmpty ||
            (options.entities.showComposerMenu && options.entities.onTagSearch != nil)
    }
}

struct ChatKitComposerOptionsMenu: View {
    let session: ChatKitSession

    var body: some View {
        Menu("Composer options", systemImage: "ellipsis.circle") {
            if session.options.entities.showComposerMenu, session.options.entities.onTagSearch != nil {
                Button("Mention", systemImage: "at") {
                    Task { await startMention() }
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
    }

    private func startMention() async {
        let text = session.composer.text
        let mentionText = text.isEmpty || text.hasSuffix(" ") ? "\(text)@" : "\(text) @"

        await session.setComposerValue(text: mentionText)
        await session.focusComposer()
    }
}
