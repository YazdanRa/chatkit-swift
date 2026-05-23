import XCTest
@testable import ChatKitSwift

final class ChatKitProtocolTests: XCTestCase {
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

    func testEncodesCreateThreadRequestWithSnakeCasePayload() throws {
        let request = ChatKitRequest.threadsCreate(
            .init(
                input: .init(
                    content: [.inputText(.init(text: "Hello"))],
                    attachments: [],
                    quotedText: nil,
                    inferenceOptions: .init(toolChoice: .init(id: "search"), model: "gpt-5.1")
                )
            )
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
