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
            #if os(iOS)
            if session.options.glassEffect {
                NavigationStack {
                    ChatKitContainerView(session: session)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbar {
                            ChatKitToolbarContent(session: session)
                        }
                }
            } else {
                ChatKitContainerView(session: session)
            }
            #else
            ChatKitContainerView(session: session)
            #endif
        }
    }
}

private struct ChatKitContainerView: View {
    @Bindable var session: ChatKitSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let usesCompactHistory = proxy.size.width < 620 && session.isHistoryVisible && session.options.history.enabled

            if session.options.glassEffect {
                ChatKitPrimaryContent(
                    session: session,
                    usesCompactHistory: usesCompactHistory,
                    sidebarWidth: min(max(proxy.size.width * 0.32, 240), 340),
                    includesComposer: false
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !usesCompactHistory {
                        ChatKitComposerView(session: session)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    if session.options.header.enabled {
                        ChatKitHeaderView(session: session)
                    }

                    ChatKitPrimaryContent(
                        session: session,
                        usesCompactHistory: usesCompactHistory,
                        sidebarWidth: min(max(proxy.size.width * 0.32, 240), 340),
                        includesComposer: true
                    )
                }
            }
        }
        .background(ChatKitStyle.background(for: session.options.theme))
        .foregroundStyle(ChatKitStyle.foreground(for: session.options.theme))
        .preferredColorScheme(ChatKitStyle.preferredColorScheme(for: session.options.theme))
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: session.isHistoryVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.options.frameTitle)
    }
}

#if os(iOS)
private struct ChatKitToolbarContent: ToolbarContent {
    let session: ChatKitSession

    var body: some ToolbarContent {
        if session.options.header.enabled {
            ToolbarItemGroup(placement: .topBarLeading) {
                if let action = session.options.header.leftAction {
                    Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                        .labelStyle(.iconOnly)
                } else if session.options.history.enabled {
                    Button("History", systemImage: "line.3.horizontal") {
                        Task { await toggleHistory() }
                    }
                    .labelStyle(.iconOnly)
                }

            }
        }

        if session.options.header.enabled || ChatKitComposerControls.showsOptionsMenu(for: session.options) {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if session.options.header.enabled, !session.isHistoryVisible, let action = session.options.header.rightAction {
                    Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                        .labelStyle(.iconOnly)
                }

                if ChatKitComposerControls.showsOptionsMenu(for: session.options) {
                    ChatKitComposerOptionsMenu(session: session)
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    private func toggleHistory() async {
        if session.isHistoryVisible {
            await session.hideHistory()
        } else {
            await session.showHistory()
        }
    }
}
#endif

private struct ChatKitPrimaryContent: View {
    let session: ChatKitSession
    let usesCompactHistory: Bool
    let sidebarWidth: CGFloat
    let includesComposer: Bool

    var body: some View {
        if usesCompactHistory {
            ChatKitHistoryView(session: session)
        } else {
            HStack(spacing: 0) {
                if session.isHistoryVisible, session.options.history.enabled {
                    ChatKitHistoryView(session: session)
                        .frame(width: sidebarWidth)
                }

                ChatKitConversationPane(session: session, includesComposer: includesComposer)
            }
        }
    }
}

private struct ChatKitConversationPane: View {
    let session: ChatKitSession
    let includesComposer: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatKitConversationBody(session: session)

            if includesComposer {
                ChatKitComposerView(session: session)
            }
        }
    }
}

private struct ChatKitConversationBody: View {
    let session: ChatKitSession

    var body: some View {
        if session.state.items.isEmpty && !session.state.isResponding && session.state.error == nil {
            ChatKitStartScreenView(session: session)
        } else {
            ChatKitMessageListView(session: session)
        }
    }
}
