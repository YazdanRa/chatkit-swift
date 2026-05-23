import SwiftUI

struct ChatKitStartScreenView: View {
    let session: ChatKitSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.options.startScreen.greeting)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !session.options.startScreen.prompts.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(session.options.startScreen.prompts) { prompt in
                            Button {
                                Task { await send(prompt) }
                            } label: {
                                Label(prompt.label, systemImage: ChatKitStyle.systemImage(for: prompt.icon ?? "sparkle"))
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func send(_ prompt: ChatKitOptions.StartScreen.Prompt) async {
        switch prompt.prompt {
        case let .text(text):
            try? await session.sendUserMessage(text: text, newThread: true)
        case let .content(content):
            try? await session.sendUserMessage(content: content, newThread: true)
        }
    }
}
