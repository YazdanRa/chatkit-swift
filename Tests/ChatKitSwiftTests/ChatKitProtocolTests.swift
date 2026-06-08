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

    func testDecodesWorkflowThreadItemAddedWithReasoningPayload() throws {
        let data = """
        {
          "type": "thread.item.added",
          "item": {
            "id": "cti_6a13cd073-da88190a924d574944-fa4bf02d4b2aa45881f18",
            "thread_id": "cthr_6a13cd041ca481908fefd-d66331d772e02d4b2aa45881f18",
            "created_at": "2026-05-25T04:16:07.240947Z",
            "type": "workflow",
            "workflow": {
              "type": "reasoning",
              "tasks": [],
              "expanded": false
            },
            "response_items": []
          }
        }
        """.data(using: .utf8)!

        let event = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data)

        guard case let .threadItemAdded(added) = event,
              case let .workflow(workflow) = added.item
        else {
            return XCTFail("Expected workflow thread.item.added")
        }
        XCTAssertEqual(workflow.id, "cti_6a13cd073-da88190a924d574944-fa4bf02d4b2aa45881f18")
        XCTAssertEqual(workflow.threadID, "cthr_6a13cd041ca481908fefd-d66331d772e02d4b2aa45881f18")
        XCTAssertEqual(workflow.workflow["type"], .string("reasoning"))
    }

    func testDecodesImageGenerationItemAndPreviewUpdateEvents() throws {
        let addedData = """
        {
          "type": "thread.item.added",
          "item": {
            "id": "imggen_1",
            "thread_id": "thr_1",
            "created_at": "2026-05-25T04:16:07.240947Z",
            "type": "image_generation",
            "image": null,
            "progress": 0.15
          }
        }
        """.data(using: .utf8)!
        let updateData = """
        {
          "type": "thread.item.updated",
          "item_id": "imggen_1",
          "update": {
            "type": "image_generation.preview.updated",
            "image": {
              "id": "img_1",
              "url": "https://example.com/preview.png"
            },
            "progress": 0.7
          }
        }
        """.data(using: .utf8)!

        let addedEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: addedData)
        let updatedEvent = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: updateData)

        guard case let .threadItemAdded(added) = addedEvent,
              case let .imageGeneration(imageGeneration) = added.item
        else {
            return XCTFail("Expected image_generation thread.item.added")
        }
        guard case let .threadItemUpdated(updated) = updatedEvent,
              case let .imageGenerationPreviewUpdated(preview) = updated.update
        else {
            return XCTFail("Expected image_generation.preview.updated")
        }

        XCTAssertEqual(imageGeneration.id, "imggen_1")
        XCTAssertEqual(imageGeneration.threadID, "thr_1")
        XCTAssertNil(imageGeneration.image)
        XCTAssertEqual(imageGeneration.progress, 0.15)
        XCTAssertEqual(updated.itemID, "imggen_1")
        XCTAssertEqual(preview.image.id, "img_1")
        XCTAssertEqual(preview.image.url.absoluteString, "https://example.com/preview.png")
        XCTAssertEqual(preview.progress, 0.7)
    }

    func testDecodesGeneratedImageUpdatedEventWithProgress() throws {
        let data = """
        {
          "type": "thread.item.updated",
          "item_id": "gen_1",
          "update": {
            "type": "generated_image.updated",
            "image": {
              "id": "img_1",
              "url": "https://example.com/generated.png"
            },
            "progress": 1.0
          }
        }
        """.data(using: .utf8)!

        let event = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data)

        guard case let .threadItemUpdated(updated) = event,
              case let .generatedImageUpdated(generatedImage) = updated.update
        else {
            return XCTFail("Expected generated_image.updated")
        }

        XCTAssertEqual(updated.itemID, "gen_1")
        XCTAssertEqual(generatedImage.image.id, "img_1")
        XCTAssertEqual(generatedImage.image.url.absoluteString, "https://example.com/generated.png")
        XCTAssertEqual(generatedImage.progress, 1.0)
    }

    func testDecodesWidgetAnnotationAndWorkflowUpdateEvents() throws {
        let annotationData = """
        {
          "type": "thread.item.updated",
          "item_id": "msg_1",
          "update": {
            "type": "assistant_message.content_part.annotation_added",
            "content_index": 0,
            "annotation_index": 0,
            "annotation": {
              "id": "ann_1",
              "type": "url",
              "title": "Source",
              "url": "https://example.com",
              "metadata": {
                "source": "docs"
              }
            }
          }
        }
        """.data(using: .utf8)!
        let widgetRootData = """
        {
          "type": "thread.item.updated",
          "item_id": "widget_1",
          "update": {
            "type": "widget.root.updated",
            "widget": {
              "type": "Card",
              "children": []
            }
          }
        }
        """.data(using: .utf8)!
        let widgetComponentData = """
        {
          "type": "thread.item.updated",
          "item_id": "widget_1",
          "update": {
            "type": "widget.component.updated",
            "component_id": "title_1",
            "component": {
              "type": "Text",
              "id": "title_1",
              "value": "Updated"
            }
          }
        }
        """.data(using: .utf8)!
        let widgetTextData = """
        {
          "type": "thread.item.updated",
          "item_id": "widget_1",
          "update": {
            "type": "widget.streaming_text.value_delta",
            "component_id": "text_1",
            "delta": " more",
            "done": false
          }
        }
        """.data(using: .utf8)!
        let workflowTaskData = """
        {
          "type": "thread.item.updated",
          "item_id": "workflow_1",
          "update": {
            "type": "workflow.task.updated",
            "task_index": 0,
            "task": {
              "id": "task_1",
              "status": "done"
            }
          }
        }
        """.data(using: .utf8)!

        guard case let .threadItemUpdated(annotationEvent) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: annotationData),
              case let .assistantMessageContentPartAnnotationAdded(annotation) = annotationEvent.update
        else {
            return XCTFail("Expected annotation update")
        }
        guard case let .threadItemUpdated(widgetRootEvent) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: widgetRootData),
              case let .widgetRootUpdated(widgetRoot) = widgetRootEvent.update
        else {
            return XCTFail("Expected widget root update")
        }
        guard case let .threadItemUpdated(widgetComponentEvent) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: widgetComponentData),
              case let .widgetComponentUpdated(widgetComponent) = widgetComponentEvent.update
        else {
            return XCTFail("Expected widget component update")
        }
        guard case let .threadItemUpdated(widgetTextEvent) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: widgetTextData),
              case let .widgetStreamingTextValueDelta(widgetText) = widgetTextEvent.update
        else {
            return XCTFail("Expected widget streaming text update")
        }
        guard case let .threadItemUpdated(workflowTaskEvent) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: workflowTaskData),
              case let .workflowTaskUpdated(workflowTask) = workflowTaskEvent.update
        else {
            return XCTFail("Expected workflow task update")
        }

        XCTAssertEqual(annotation.annotation.title, "Source")
        XCTAssertEqual(annotation.annotation.metadata["source"], .string("docs"))
        XCTAssertEqual(widgetRoot.widget.type, "Card")
        XCTAssertEqual(widgetComponent.componentID, "title_1")
        XCTAssertEqual(widgetComponent.component.raw["value"], .string("Updated"))
        XCTAssertEqual(widgetText.componentID, "text_1")
        XCTAssertEqual(widgetText.delta, " more")
        XCTAssertEqual(widgetText.done, false)
        XCTAssertEqual(workflowTask.taskIndex, 0)
        XCTAssertEqual(workflowTask.task["status"], .string("done"))
    }

    func testDecodesKnownRuntimeEventsAndPreservesUnknownEvents() throws {
        let updatedData = """
        {
          "type": "thread.updated",
          "thread": {
            "id": "thr_1",
            "title": "Renamed",
            "created_at": "2026-05-23T22:26:42.151025Z",
            "status": { "type": "active" },
            "metadata": {},
            "items": { "data": [], "has_more": false }
          }
        }
        """.data(using: .utf8)!
        let removedData = """
        {
          "type": "thread.item.removed",
          "item_id": "msg_removed"
        }
        """.data(using: .utf8)!
        let replacedData = """
        {
          "type": "thread.item.replaced",
          "item": {
            "id": "msg_replaced",
            "thread_id": "thr_1",
            "created_at": "2026-05-23T22:26:43.151025Z",
            "type": "assistant_message",
            "content": [
              { "type": "output_text", "text": "Replacement", "annotations": [] }
            ]
          }
        }
        """.data(using: .utf8)!
        let progressData = """
        {
          "type": "progress_update",
          "icon": "sparkle",
          "text": "Searching"
        }
        """.data(using: .utf8)!
        let clientEffectData = """
        {
          "type": "client_effect",
          "name": "deeplink",
          "data": {
            "url": "chatkit-link://open?id=1"
          }
        }
        """.data(using: .utf8)!
        let noticeData = """
        {
          "type": "notice",
          "level": "warning",
          "title": "Usage",
          "message": "Limit soon"
        }
        """.data(using: .utf8)!
        let errorData = """
        {
          "type": "error",
          "code": "stream.error",
          "message": "Try again",
          "allow_retry": true
        }
        """.data(using: .utf8)!
        let unknownData = """
        {
          "type": "blocked_features",
          "blocked_features": ["attachments"],
          "reason": "policy"
        }
        """.data(using: .utf8)!

        guard case let .threadUpdated(updated) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: updatedData) else {
            return XCTFail("Expected thread.updated")
        }
        guard case let .threadItemRemoved(removed) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: removedData) else {
            return XCTFail("Expected thread.item.removed")
        }
        guard case let .threadItemReplaced(replaced) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: replacedData),
              case let .assistantMessage(replacedMessage) = replaced.item
        else {
            return XCTFail("Expected thread.item.replaced")
        }
        guard case let .progressUpdate(progress) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: progressData) else {
            return XCTFail("Expected progress_update")
        }
        guard case let .clientEffect(effect) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: clientEffectData) else {
            return XCTFail("Expected client_effect")
        }
        guard case let .notice(notice) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: noticeData) else {
            return XCTFail("Expected notice")
        }
        guard case let .error(error) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: errorData) else {
            return XCTFail("Expected error")
        }
        guard case let .unknown(type, raw) = try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: unknownData) else {
            return XCTFail("Expected unknown event preservation")
        }

        XCTAssertEqual(updated.thread.title, "Renamed")
        XCTAssertEqual(removed.itemID, "msg_removed")
        XCTAssertEqual(replacedMessage.content.first?.text, "Replacement")
        XCTAssertEqual(progress.icon, "sparkle")
        XCTAssertEqual(effect.data["url"], .string("chatkit-link://open?id=1"))
        XCTAssertEqual(notice.level, .warning)
        XCTAssertEqual(error.allowRetry, true)
        XCTAssertEqual(type, "blocked_features")
        XCTAssertEqual(raw["blocked_features"], .array([.string("attachments")]))
        XCTAssertEqual(raw["reason"], .string("policy"))
    }

    func testPreservesUnknownThreadItemUpdates() throws {
        let data = """
        {
          "type": "assistant_message.content_part.inline_widget_added",
          "content_index": 0,
          "inline_widget_index": 0,
          "inline_widget": {
            "type": "Card",
            "children": []
          }
        }
        """.data(using: .utf8)!

        let update = try ChatKitJSON.decoder.decode(ChatKitThreadItemUpdate.self, from: data)

        guard case let .unknown(type, raw) = update else {
            return XCTFail("Expected unknown inline widget update preservation")
        }
        XCTAssertEqual(type, "assistant_message.content_part.inline_widget_added")
        XCTAssertEqual(raw["content_index"], .number(0))
        XCTAssertEqual(raw["inline_widget_index"], .number(0))
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

    func testEncodesAllSupportedRequestEnvelopeTypesAndStreamingFlags() throws {
        let input = ChatKitUserMessageInput(content: [.inputText(.init(text: "Hello"))])
        let action = ChatKitAction(type: "widget.action", payload: ["value": .string("ok")])
        let submission = ChatKitStructuredInputSubmission(answers: ["field_1": .init(values: ["yes"])])
        let samples: [(ChatKitRequest, String, Bool)] = [
            (.threadsGetByID(.init(threadID: "thr_1")), "threads.get_by_id", false),
            (.threadsCreate(.init(input: input)), "threads.create", true),
            (.threadsList(.init(limit: 20, order: .descending, after: "cursor_1")), "threads.list", false),
            (.threadsAddUserMessage(.init(input: input, threadID: "thr_1")), "threads.add_user_message", true),
            (.threadsAddClientToolOutput(.init(threadID: "thr_1", itemID: "item_1", callID: "call_1", result: .object(["ok": .bool(true)]))), "threads.add_client_tool_output", true),
            (.threadsAddStructuredInput(.init(threadID: "thr_1", itemID: "item_1", input: submission)), "threads.add_structured_input", true),
            (.threadsCustomAction(.init(threadID: "thr_1", itemID: "item_1", action: action)), "threads.custom_action", true),
            (.threadsSyncCustomAction(.init(threadID: "thr_1", itemID: "item_1", action: action)), "threads.sync_custom_action", false),
            (.threadsRetryAfterItem(.init(threadID: "thr_1", itemID: "item_1")), "threads.retry_after_item", true),
            (.threadsUpdate(.init(threadID: "thr_1", title: "Renamed")), "threads.update", false),
            (.threadsDelete(.init(threadID: "thr_1")), "threads.delete", false),
            (.itemsList(.init(threadID: "thr_1", limit: 50, order: .ascending, after: "item_cursor")), "items.list", false),
            (.itemsFeedback(.init(threadID: "thr_1", itemIDs: ["item_1"], kind: .positive)), "items.feedback", false),
            (.attachmentsCreate(.init(name: "photo.png", size: 1024, mimeType: "image/png")), "attachments.create", false),
            (.attachmentsProcess(.init(attachmentID: "file_1", name: "photo.png", width: 640, height: 480)), "attachments.process", false),
            (.attachmentsGetPreview(.init(attachmentID: "file_1", conversationID: "thr_1")), "attachments.get_preview", false),
            (.attachmentsDelete(.init(attachmentID: "file_1")), "attachments.delete", false),
            (.inputTranscribe(.init(audioBase64: "AAAA", mimeType: "audio/wav")), "input.transcribe", false),
        ]

        for (request, expectedType, expectedStreaming) in samples {
            let object = try encodedRequestObject(request)

            XCTAssertEqual(object["type"] as? String, expectedType)
            XCTAssertNotNil(object["params"], "Expected params for \(expectedType)")
            XCTAssertEqual(request.isStreaming, expectedStreaming, "Unexpected streaming flag for \(expectedType)")
        }
    }

    func testEncodesAttachmentProcessRequestWithImageDimensions() throws {
        let request = ChatKitRequest.attachmentsProcess(
            .init(attachmentID: "file_123", name: "photo.png", width: 640, height: 480),
        )

        let object = try encodedRequestObject(request)
        let params = try XCTUnwrap(object["params"] as? [String: Any])

        XCTAssertEqual(object["type"] as? String, "attachments.process")
        XCTAssertEqual(params["attachment_id"] as? String, "file_123")
        XCTAssertEqual(params["name"] as? String, "photo.png")
        XCTAssertEqual(params["width"] as? Int, 640)
        XCTAssertEqual(params["height"] as? Int, 480)
        XCTAssertFalse(request.isStreaming)
    }

    func testEncodesAttachmentPreviewRequestForConversationAndSharedConversation() throws {
        let conversationRequest = ChatKitRequest.attachmentsGetPreview(
            .init(attachmentID: "file_123", conversationID: "thr_abc"),
        )
        let sharedConversationRequest = ChatKitRequest.attachmentsGetPreview(
            .init(attachmentID: "file_456", sharedConversationID: "share_def"),
        )

        let conversationObject = try encodedRequestObject(conversationRequest)
        let conversationParams = try XCTUnwrap(conversationObject["params"] as? [String: Any])
        let sharedObject = try encodedRequestObject(sharedConversationRequest)
        let sharedParams = try XCTUnwrap(sharedObject["params"] as? [String: Any])

        XCTAssertEqual(conversationObject["type"] as? String, "attachments.get_preview")
        XCTAssertEqual(conversationParams["attachment_id"] as? String, "file_123")
        XCTAssertEqual(conversationParams["conversation_id"] as? String, "thr_abc")
        XCTAssertNil(conversationParams["shared_conversation_id"])
        XCTAssertFalse(conversationRequest.isStreaming)

        XCTAssertEqual(sharedObject["type"] as? String, "attachments.get_preview")
        XCTAssertEqual(sharedParams["attachment_id"] as? String, "file_456")
        XCTAssertEqual(sharedParams["shared_conversation_id"] as? String, "share_def")
        XCTAssertNil(sharedParams["conversation_id"])
        XCTAssertFalse(sharedConversationRequest.isStreaming)
    }

    private func encodedRequestObject(_ request: ChatKitRequest) throws -> [String: Any] {
        let data = try ChatKitJSON.encoder.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
