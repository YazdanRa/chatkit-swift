import SwiftUI

struct ChatKitHeaderView: View {
    let session: ChatKitSession

    var body: some View {
        HStack(spacing: 12) {
            if let action = session.options.header.leftAction {
                Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                    .chatKitHeaderButtonStyle()
            } else if session.options.history.enabled {
                Button("History", systemImage: "line.3.horizontal") {
                    Task { await toggleHistory() }
                }
                .chatKitHeaderButtonStyle()
            }

            if session.options.header.title.enabled {
                Text(title)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.tertiary)
                    }
            } else {
                EmptyView()
            }

            Spacer()

            if !session.isHistoryVisible, let action = session.options.header.rightAction {
                Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                    .chatKitHeaderButtonStyle()
            }

            if ChatKitComposerControls.showsOptionsMenu(for: session.options) {
                ChatKitComposerOptionsMenu(session: session)
                    .chatKitHeaderButtonStyle()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var title: String {
        session.options.header.title.text ?? session.state.currentThread?.title ?? "Chat"
    }

    private func toggleHistory() async {
        if session.isHistoryVisible {
            await session.hideHistory()
        } else {
            await session.showHistory()
        }
    }
}

private extension View {
    func chatKitHeaderButtonStyle() -> some View {
        labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title3)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
    }
}
