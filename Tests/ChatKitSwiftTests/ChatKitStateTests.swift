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

    func testAppliesWidgetUpdatesToNestedWidgetTree() {
        var state = ChatKitConversationState()
        let widget = ChatKitWidgetItem(
            id: "widget_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            widget: .init(type: "Card", raw: [
                "type": .string("Card"),
                "children": .array([
                    .object([
                        "type": .string("Text"),
                        "id": .string("title_1"),
                        "value": .string("Initial"),
                    ]),
                    .object([
                        "type": .string("Button"),
                        "id": .string("button_1"),
                        "label": .string("Run"),
                    ]),
                ]),
            ]),
        )

        state.apply(.threadItemAdded(.init(item: .widget(widget))))
        state.apply(.threadItemUpdated(.init(
            itemID: "widget_1",
            update: .widgetComponentUpdated(.init(
                componentID: "title_1",
                component: .init(type: "Text", id: "title_1", raw: [
                    "type": .string("Text"),
                    "id": .string("title_1"),
                    "value": .string("Updated"),
                ]),
            )),
        )))
        state.apply(.threadItemUpdated(.init(
            itemID: "widget_1",
            update: .widgetStreamingTextValueDelta(.init(componentID: "title_1", delta: " more", done: false)),
        )))
        state.apply(.threadItemUpdated(.init(
            itemID: "widget_1",
            update: .widgetStreamingTextValueDelta(.init(componentID: "button_1", delta: " ignored", done: true)),
        )))

        guard case let .widget(updated)? = state.items.first else {
            return XCTFail("Expected widget item")
        }
        XCTAssertEqual(updated.widget.children.first?.raw["value"], .string("Updated more"))
        XCTAssertEqual(updated.widget.children.first?.raw["done"], .bool(false))
        XCTAssertNil(updated.widget.children.last?.raw["value"])
    }

    func testAppliesImageGenerationPreviewUpdate() {
        var state = ChatKitConversationState()
        let item = ChatKitImageGenerationItem(
            id: "imggen_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            image: nil,
            progress: 0.15,
        )
        let preview = ChatKitGeneratedImageItem.GeneratedImage(
            id: "img_1",
            url: URL(string: "https://example.com/preview.png")!,
        )

        state.apply(.threadItemAdded(.init(item: .imageGeneration(item))))
        state.apply(.threadItemUpdated(.init(
            itemID: "imggen_1",
            update: .imageGenerationPreviewUpdated(.init(image: preview, progress: 0.7)),
        )))

        guard case let .imageGeneration(updated)? = state.items.first else {
            return XCTFail("Expected image_generation item")
        }
        XCTAssertEqual(updated.image?.url.absoluteString, "https://example.com/preview.png")
        XCTAssertEqual(updated.progress, 0.7)
    }

    func testAppliesGeneratedImageUpdatedEvent() {
        var state = ChatKitConversationState()
        let item = ChatKitGeneratedImageItem(
            id: "gen_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            image: nil,
        )
        let image = ChatKitGeneratedImageItem.GeneratedImage(
            id: "img_1",
            url: URL(string: "https://example.com/generated.png")!,
        )

        state.apply(.threadItemAdded(.init(item: .generatedImage(item))))
        state.apply(.threadItemUpdated(.init(
            itemID: "gen_1",
            update: .generatedImageUpdated(.init(image: image, progress: 1.0)),
        )))

        guard case let .generatedImage(updated)? = state.items.first else {
            return XCTFail("Expected generated_image item")
        }
        XCTAssertEqual(updated.image?.url.absoluteString, "https://example.com/generated.png")
        XCTAssertEqual(updated.image?.progress, 1.0)
    }
}
