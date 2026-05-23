import SwiftUI

struct ChatKitHeaderView: View {
    let session: ChatKitSession

    var body: some View {
        HStack(spacing: 12) {
            if let action = session.options.header.leftAction {
                Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                    .buttonStyle(.borderless)
            } else if session.options.history.enabled {
                Button("History", systemImage: "sidebar.left") {
                    Task { await session.showHistory() }
                }
                .buttonStyle(.borderless)
            }

            if session.options.header.title.enabled {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            if session.isHistoryVisible {
                Button("Hide history", systemImage: "xmark") {
                    Task { await session.hideHistory() }
                }
                .buttonStyle(.borderless)
            }

            if let action = session.options.header.rightAction {
                Button(action.accessibilityLabel, systemImage: ChatKitStyle.systemImage(for: action.icon), action: action.perform)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var title: String {
        session.options.header.title.text ?? session.state.currentThread?.title ?? "Chat"
    }
}
