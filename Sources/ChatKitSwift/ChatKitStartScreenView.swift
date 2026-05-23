import SwiftUI

struct ChatKitStartScreenView: View {
    let session: ChatKitSession

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(session.options.startScreen.greeting)
                        .font(.title2)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !session.options.startScreen.prompts.isEmpty {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(session.options.startScreen.prompts) { prompt in
                                Button(action: { Task { await send(prompt) } }) {
                                    Label(prompt.label, systemImage: ChatKitStyle.systemImage(for: prompt.icon ?? "sparkle"))
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, startContentTopPadding(for: proxy.size.height))
                .padding(.bottom, 112)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
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

    private func startContentTopPadding(for height: CGFloat) -> CGFloat {
        min(max(height * 0.32, 220), 300)
    }
}
