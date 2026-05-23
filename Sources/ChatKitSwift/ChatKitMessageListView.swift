import SwiftUI

struct ChatKitMessageListView: View {
    let session: ChatKitSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.state.items) { item in
                        ChatKitMessageRowView(item: item, session: session)
                            .id(item.id)
                    }

                    if let progress = session.state.progress, session.state.isResponding {
                        ChatKitProgressView(progress: progress)
                    }

                    if let error = session.state.error {
                        ChatKitErrorView(error: error)
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.visible)
            .onChange(of: session.state.items.count) {
                guard session.options.thread.autoScroll,
                      let lastID = session.state.items.last?.id else {
                    return
                }
                if reduceMotion {
                    proxy.scrollTo(lastID, anchor: .bottom)
                } else {
                    withAnimation(.smooth(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }
}
