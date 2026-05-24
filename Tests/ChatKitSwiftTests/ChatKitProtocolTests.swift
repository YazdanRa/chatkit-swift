@testable import ChatKitSwift
import XCTest

final class ChatKitProtocolTests: XCTestCase {
    func testDecodesThreadCreatedWithServerTimestamp() throws {
        let data = """
        {
          "type": "thread.created",
          "thread": {
            "id": "thr_ee5a0b6e",
            "created_at": "2026-05-23T22:26:42.151025",
            "status": { "type": "active" },
            "metadata": {},
            "items": { "data": [], "has_more": false }
          }
        }
        """.data(using: .utf8)!

        let event = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data)

        guard case let .threadCreated(created) = event else {
            return XCTFail("Expected thread.created")
        }
        XCTAssertEqual(created.thread.id, "thr_ee5a0b6e")
    }

    func testDecodesThreadItemDoneWithServerTimestamp() throws {
        let data = """
        {
          "type": "thread.item.done",
          "item": {
            "id": "msg_9af59887",
            "thread_id": "thr_ee5a0b6e",
            "created_at": "2026-05-23T22:26:42.470432",
            "type": "user_message",
            "content": [
              { "type": "input_text", "text": "Hi there!" }
            ],
            "attachments": [],
            "inference_options": {}
          }
        }
        """.data(using: .utf8)!

        let event = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data)

        guard case let .threadItemDone(done) = event,
              case let .userMessage(message) = done.item
        else {
            return XCTFail("Expected user thread.item.done")
        }
        XCTAssertEqual(message.id, "msg_9af59887")
        XCTAssertEqual(message.threadID, "thr_ee5a0b6e")
    }

    func testDecodesAssistantTextDeltaStreamEvent() throws {
        let data = """
        {
          "type": "thread.item.updated",
          "item_id": "msg_2",
          "update": {
            "type": "assistant_message.content_part.text_delta",
            "content_index": 0,
            "delta": " there"
          }
        }
        """.data(using: .utf8)!

        let event = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data)

        guard case let .threadItemUpdated(updated) = event else {
            return XCTFail("Expected thread.item.updated")
        }
        XCTAssertEqual(updated.itemID, "msg_2")
        XCTAssertEqual(updated.update, .assistantMessageContentPartTextDelta(.init(contentIndex: 0, delta: " there")))
    }

    func testDecodesServerStreamOptionsAndContentPartUpdates() throws {
        let streamOptionsData = """
        {
          "type": "stream_options",
          "stream_options": { "allow_cancel": true }
        }
        """.data(using: .utf8)!
        let contentAddedData = """
        {
          "type": "thread.item.updated",
          "item_id": "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4",
          "update": {
            "type": "assistant_message.content_part.added",
            "content_index": 0,
            "content": { "annotations": [], "text": "", "type": "output_text" }
          }
        }
        """.data(using: .utf8)!
        let contentDoneData = """
        {
          "type": "thread.item.updated",
          "item_id": "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4",
          "update": {
            "type": "assistant_message.content_part.done",
            "content_index": 0,
            "content": { "annotations": [], "text": "Hi! How can I help?", "type": "output_text" }
          }
        }
        """.data(using: .utf8)!

        let streamOptionsEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: streamOptionsData)
        let contentAddedEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: contentAddedData)
        let contentDoneEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: contentDoneData)

        XCTAssertEqual(streamOptionsEvent, .streamOptions(.init(streamOptions: .init(allowCancel: true))))

        guard case let .threadItemUpdated(contentAdded) = contentAddedEvent,
              case let .assistantMessageContentPartAdded(added) = contentAdded.update
        else {
            return XCTFail("Expected assistant content part added")
        }
        guard case let .threadItemUpdated(contentDone) = contentDoneEvent,
              case let .assistantMessageContentPartDone(done) = contentDone.update
        else {
            return XCTFail("Expected assistant content part done")
        }
        XCTAssertEqual(contentAdded.itemID, "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4")
        XCTAssertEqual(added.content.text, "")
        XCTAssertEqual(contentDone.itemID, "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4")
        XCTAssertEqual(done.content.text, "Hi! How can I help?")
    }

    func testDecodesAssistantMessageLifecycleFromServerEvents() throws {
        let addedData = """
        {
          "type": "thread.item.added",
          "item": {
            "id": "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4",
            "thread_id": "thr_ee5a0b6e",
            "created_at": "2026-05-23T22:26:44.967426",
            "type": "assistant_message",
            "content": []
          }
        }
        """.data(using: .utf8)!
        let doneData = """
        {
          "type": "thread.item.done",
          "item": {
            "id": "msg_0840b7cadc11da96006a1229a4edb48193930356d0ddd10ec4",
            "thread_id": "thr_ee5a0b6e",
            "created_at": "2026-05-23T22:26:45.144846",
            "type": "assistant_message",
            "content": [
              { "annotations": [], "text": "Hi! How can I help?", "type": "output_text" }
            ]
          }
        }
        """.data(using: .utf8)!

        let addedEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: addedData)
        let doneEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: doneData)

        guard case let .threadItemAdded(added) = addedEvent,
              case let .assistantMessage(addedMessage) = added.item
        else {
            return XCTFail("Expected assistant thread.item.added")
        }
        guard case let .threadItemDone(done) = doneEvent,
              case let .assistantMessage(doneMessage) = done.item
        else {
            return XCTFail("Expected assistant thread.item.done")
        }
        XCTAssertEqual(addedMessage.content, [])
        XCTAssertEqual(doneMessage.content.map(\.text).joined(), "Hi! How can I help?")
    }

    func testEncodesCreateThreadRequestWithSnakeCasePayload() throws {
        let request = ChatKitRequest.threadsCreate(
            .init(
                input: .init(
                    content: [.inputText(.init(text: "Hello"))],
                    attachments: [],
                    quotedText: nil,
                    inferenceOptions: .init(toolChoice: .init(id: "search"), model: "gpt-5.1"),
                ),
            ),
        )

        let data = try ChatKitJSON.encoder.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let params = object?["params"] as? [String: Any]
        let input = params?["input"] as? [String: Any]
        let inferenceOptions = input?["inference_options"] as? [String: Any]
        let toolChoice = inferenceOptions?["tool_choice"] as? [String: Any]

        XCTAssertEqual(object?["type"] as? String, "threads.create")
        XCTAssertEqual(input?["quoted_text"] as? String, nil)
        XCTAssertEqual(toolChoice?["id"] as? String, "search")
        XCTAssertEqual(inferenceOptions?["model"] as? String, "gpt-5.1")
    }
}
