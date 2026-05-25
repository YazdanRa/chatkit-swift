import ChatKitSwift
import SwiftUI

struct ChatScreen: View {
    private let optionsResult: Result<ChatKitOptions, Error>

    init(configuration: OpenAIHostedChatKitConfiguration = .init()) {
        optionsResult = configuration.options()
    }

    var body: some View {
        switch optionsResult {
        case let .success(options):
            ChatKitView(options: options)
        case let .failure(error):
            ConfigurationErrorView(message: error.localizedDescription)
        }
    }
}

private struct ConfigurationErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("ChatKitSwiftDemo", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text(message)
        }
        .padding()
    }
}
