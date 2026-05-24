@testable import ChatKitSwift
import XCTest

final class ChatKitStateTests: XCTestCase {
    func testAppliesThreadAndAssistantMessageEvents() {
        var state = ChatKitConversationState()
        let thread = ChatKitThread(
            title: "Demo",
            id: "thread_1",
            createdAt: Date(timeIntervalSince1970: 1),
            status: .active(.init()),
            allowedImageDomains: nil,
            metadata: [:],
            items: .init(data: [], hasMore: false, after: nil),
        )
        let message = ChatKitAssistantMessageItem(
            id: "msg_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            content: [.init(text: "Hi", annotations: [])],
        )

        state.apply(.threadCreated(.init(thread: thread)))
        state.apply(.threadItemAdded(.init(item: .assistantMessage(message))))
        state.apply(.threadItemUpdated(.init(
            itemID: "msg_1",
            update: .assistantMessageContentPartTextDelta(.init(contentIndex: 0, delta: " there")),
        )))
        state.apply(.threadItemDone(.init(item: .assistantMessage(message.appendingText(" there")))))

        XCTAssertEqual(state.currentThread?.id, "thread_1")
        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items.first?.assistantText, "Hi there")
        XCTAssertFalse(state.isResponding)
    }

    func testAppliesProgressErrorAndNoticeEvents() {
        var state = ChatKitConversationState()

        state.apply(.progressUpdate(.init(icon: "sparkle", text: "Searching")))
        state.apply(.error(.init(code: "stream_error", message: "Try again", allowRetry: true)))
        state.apply(.notice(.init(level: .warning, message: "Limit soon", title: "Usage")))

        XCTAssertEqual(state.progress?.text, "Searching")
        XCTAssertEqual(state.error?.message, "Try again")
        XCTAssertEqual(state.notices.map(\.message), ["Limit soon"])
    }
}
