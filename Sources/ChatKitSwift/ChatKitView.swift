import SwiftUI

public struct ChatKitView: View {
    private let injectedSession: ChatKitSession?
    @State private var ownedSession: ChatKitSession?

    public init(session: ChatKitSession) {
        injectedSession = session
        _ownedSession = State(initialValue: nil)
    }

    @MainActor
    public init(options: ChatKitOptions, transport: (any ChatKitTransport)? = nil) {
        injectedSession = nil
        _ownedSession = State(initialValue: ChatKitSession(options: options, transport: transport))
    }

    public var body: some View {
        if let session = injectedSession ?? ownedSession {
            ChatKitContainerView(session: session)
        }
    }
}

private struct ChatKitContainerView: View {
    @Bindable var session: ChatKitSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if session.options.header.enabled {
                ChatKitHeaderView(session: session)
            }

            Divider()

            HStack(spacing: 0) {
                if session.isHistoryVisible, session.options.history.enabled {
                    ChatKitHistoryView(session: session)
                    Divider()
                }

                VStack(spacing: 0) {
                    if session.state.items.isEmpty {
                        ChatKitStartScreenView(session: session)
                    } else {
                        ChatKitMessageListView(session: session)
                    }

                    if let disclaimer = session.options.disclaimer {
                        ChatKitDisclaimerView(disclaimer: disclaimer)
                    }

                    ChatKitComposerView(session: session)
                }
            }
        }
        .background(ChatKitStyle.background(for: session.options.theme))
        .foregroundStyle(ChatKitStyle.foreground(for: session.options.theme))
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: session.isHistoryVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.options.frameTitle)
    }
}
