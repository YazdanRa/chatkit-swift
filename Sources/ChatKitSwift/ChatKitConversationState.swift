import Foundation

public struct ChatKitConversationState: Equatable, Sendable {
    public var currentThread: ChatKitThread?
    public var threads: [ChatKitThread]
    public var items: [ChatKitThreadItem]
    public var isResponding: Bool
    public var allowsCancel: Bool
    public var progress: ChatKitEvent.ProgressUpdate?
    public var error: ChatKitEvent.ErrorEvent?
    public var notices: [ChatKitEvent.Notice]
    public var effects: [ChatKitEvent.ClientEffect]

    public init(
        currentThread: ChatKitThread? = nil,
        threads: [ChatKitThread] = [],
        items: [ChatKitThreadItem] = [],
        isResponding: Bool = false,
        allowsCancel: Bool = false,
        progress: ChatKitEvent.ProgressUpdate? = nil,
        error: ChatKitEvent.ErrorEvent? = nil,
        notices: [ChatKitEvent.Notice] = [],
        effects: [ChatKitEvent.ClientEffect] = []
    ) {
        self.currentThread = currentThread
        self.threads = threads
        self.items = items
        self.isResponding = isResponding
        self.allowsCancel = allowsCancel
        self.progress = progress
        self.error = error
        self.notices = notices
        self.effects = effects
    }

    public mutating func apply(_ event: ChatKitEvent) {
        switch event {
        case let .threadCreated(event):
            currentThread = event.thread
            upsertThread(event.thread)
            items = event.thread.items.data
        case let .threadUpdated(event):
            currentThread = event.thread
            upsertThread(event.thread)
        case let .threadItemAdded(event):
            upsertItem(event.item)
            isResponding = true
            progress = nil
        case let .threadItemUpdated(event):
            guard let index = items.firstIndex(where: { $0.id == event.itemID }) else {
                return
            }
            items[index] = items[index].applying(event.update)
        case let .threadItemDone(event):
            upsertItem(event.item)
            isResponding = false
            progress = nil
        case let .threadItemRemoved(event):
            items.removeAll { $0.id == event.itemID }
        case let .threadItemReplaced(event):
            upsertItem(event.item)
        case let .streamOptions(event):
            allowsCancel = event.streamOptions.allowCancel
        case let .progressUpdate(event):
            progress = event
            isResponding = true
        case let .clientEffect(event):
            effects.append(event)
        case let .error(event):
            error = event
            isResponding = false
        case let .notice(event):
            notices.append(event)
        case .unknown:
            break
        }
    }

    public mutating func replaceThreads(_ threads: [ChatKitThread]) {
        self.threads = threads
        if let currentThread,
           let refreshed = threads.first(where: { $0.id == currentThread.id }) {
            self.currentThread = refreshed
        }
    }

    public mutating func replaceCurrentThread(_ thread: ChatKitThread) {
        currentThread = thread
        items = thread.items.data
        upsertThread(thread)
    }

    public mutating func replaceItems(_ items: [ChatKitThreadItem]) {
        self.items = items.sorted { $0.createdAt < $1.createdAt }
    }

    private mutating func upsertThread(_ thread: ChatKitThread) {
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.insert(thread, at: 0)
        }
    }

    private mutating func upsertItem(_ item: ChatKitThreadItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
            items.sort { $0.createdAt < $1.createdAt }
        }
    }
}
