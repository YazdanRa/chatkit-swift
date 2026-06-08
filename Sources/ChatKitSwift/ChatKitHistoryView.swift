import SwiftUI

struct ChatKitHistoryView: View {
    let session: ChatKitSession
    @State private var isLoading = false
    @State private var renamingThread: ChatKitThread?
    @State private var renameTitle = ""
    @State private var renameError: String?

    var body: some View {
        List {
            ForEach(session.state.threads) { thread in
                Button {
                    Task { try? await session.setThreadId(thread.id) }
                } label: {
                    Text(thread.title ?? "Untitled thread")
                        .font(.title3)
                        .lineLimit(2)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(thread.title ?? "Untitled thread")
                .listRowInsets(.init(top: 0, leading: 24, bottom: 0, trailing: 24))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if session.options.history.showRename {
                        Button("Rename", systemImage: "pencil") {
                            beginRename(thread)
                        }
                    }
                    if session.options.history.showDelete {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { try? await session.deleteThread(thread.id) }
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
        .environment(\.defaultMinListRowHeight, 44)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .task {
            guard !isLoading else { return }
            isLoading = true
            try? await session.loadThreads()
            isLoading = false
        }
        .alert("Rename chat", isPresented: isRenamePresented) {
            TextField("Thread title", text: $renameTitle)
            Button("Cancel", role: .cancel) {
                clearRenameState()
            }
            Button("Rename") {
                Task { await renameThread() }
            }
        } message: {
            if let renameError {
                Text(renameError)
            }
        }
    }

    private var isRenamePresented: Binding<Bool> {
        Binding {
            renamingThread != nil
        } set: { isPresented in
            if !isPresented {
                clearRenameState()
            }
        }
    }

    private func beginRename(_ thread: ChatKitThread) {
        renamingThread = thread
        renameTitle = thread.title ?? ""
        renameError = nil
    }

    private func renameThread() async {
        guard let thread = renamingThread else {
            return
        }

        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            renameError = "Enter a title."
            return
        }

        do {
            try await session.updateThreadTitle(title, threadID: thread.id)
            clearRenameState()
        } catch {
            renameError = error.localizedDescription
        }
    }

    private func clearRenameState() {
        renamingThread = nil
        renameTitle = ""
        renameError = nil
    }
}
