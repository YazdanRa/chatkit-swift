import SwiftUI

struct ChatKitHistoryView: View {
    let session: ChatKitSession
    @State private var isLoading = false

    var body: some View {
        List {
            ForEach(session.state.threads) { thread in
                Button {
                    Task { try? await session.setThreadId(thread.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.title ?? "Untitled thread")
                            .font(.body)
                            .lineLimit(2)
                        Text(thread.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(thread.title ?? "Untitled thread")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if session.options.history.showRename {
                        Button("Rename", systemImage: "pencil") {
                            Task { try? await session.updateCurrentThreadTitle(thread.title ?? "Untitled thread") }
                        }
                    }
                    if session.options.history.showDelete {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { try? await session.deleteThread(thread.id) }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)
        .task {
            guard !isLoading else { return }
            isLoading = true
            try? await session.loadThreads()
            isLoading = false
        }
    }
}
