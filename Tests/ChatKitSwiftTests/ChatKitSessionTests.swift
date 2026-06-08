@testable import ChatKitSwift
import XCTest

@MainActor
final class ChatKitSessionTests: XCTestCase {
    func testSendUserMessageCreatesThreadAndAppliesStream() async throws {
        let transport = RecordingTransport(events: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init(),
            ))),
            .threadItemDone(.init(item: .assistantMessage(.init(
                id: "msg_1",
                threadID: "thread_1",
                createdAt: Date(timeIntervalSince1970: 2),
                content: [.init(text: "Hello")],
            )))),
        ])
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )

        try await session.sendUserMessage(text: "Hi")

        let streamedRequestTypes = await transport.streamedRequestTypes()
        XCTAssertEqual(streamedRequestTypes, ["threads.create"])
        XCTAssertEqual(session.state.currentThread?.id, "thread_1")
        XCTAssertEqual(session.state.items.first?.assistantText, "Hello")
    }

    func testSendUserMessageKeepsUserMessageWhenCreatedThreadDoesNotEchoIt() async throws {
        let transport = RecordingTransport(events: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init(),
            ))),
        ])
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )

        try await session.sendUserMessage(text: "Hi")

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(session.state.items.first?.threadID, "thread_1")
    }

    func testSendUserMessageDoesNotDuplicateUserMessageWhenCreatedThreadEchoesIt() async throws {
        let echoedMessage = ChatKitThreadItem.userMessage(.init(
            id: "msg_user_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            content: [.inputText(.init(text: "Hi"))],
        ))
        let transport = RecordingTransport(events: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init(data: [echoedMessage]),
            ))),
        ])
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )

        try await session.sendUserMessage(text: "Hi")

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(session.state.items.first?.id, "msg_user_1")
    }

    func testSendUserMessageKeepsUserMessageAndStoresReadableErrorWhenStreamFails() async throws {
        let errorPayload = Data(#"{"detail":"Invalid token"}"#.utf8)
        let transport = RecordingTransport(error: ChatKitTransportError.httpStatus(401, errorPayload))
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )

        do {
            try await session.sendUserMessage(text: "Hi")
            XCTFail("Expected send to fail")
        } catch {}

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(session.state.error?.message, "HTTP 401: Invalid token")
    }

    func testSendUserMessageStoresReadablePayloadErrorWhenStreamEventCannotDecode() async throws {
        let payload = #"{"type":"thread.item.done","item":{"type":"assistant_message","created_at":"not-a-date"}}"#
        let transport = RecordingTransport(error: ChatKitTransportError.eventDecodingFailed(payload: payload, reason: "Invalid ISO-8601 date"))
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )

        do {
            try await session.sendUserMessage(text: "Hi")
            XCTFail("Expected send to fail")
        } catch {}

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(
            session.state.error?.message,
            #"Invalid ChatKit event payload: Invalid ISO-8601 date. Payload: {"type":"thread.item.done","item":{"type":"assistant_message","created_at":"not-a-date"}}"#,
        )
    }

    func testSelectingThreadHidesVisibleHistory() async throws {
        let transport = ThreadLookupTransport(thread: .init(
            title: "Saved chat",
            id: "thread_1",
            createdAt: Date(timeIntervalSince1970: 1),
            items: .init(),
        ))
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: transport,
        )
        await session.showHistory()

        try await session.setThreadId("thread_1")

        XCTAssertEqual(session.state.currentThread?.id, "thread_1")
        XCTAssertFalse(session.isHistoryVisible)
    }

    func testSetComposerValuePreservesSelectedToolWhenToolIsOmitted() async throws {
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: RecordingTransport(),
        )

        await session.setComposerValue(selectedToolID: "search")
        await session.setComposerValue(text: "Prefilled message")

        XCTAssertEqual(session.composer.text, "Prefilled message")
        XCTAssertEqual(session.composer.selectedToolID, "search")
    }

    func testSetComposerValueClearsSelectedToolWhenNilIsExplicit() async throws {
        let session = try ChatKitSession(
            options: .init(api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit")))),
            transport: RecordingTransport(),
        )

        await session.setComposerValue(selectedToolID: "search")
        await session.setComposerValue(selectedToolID: nil)

        XCTAssertNil(session.composer.selectedToolID)
    }

    func testSetComposerValueOnlyEmitsToolChangeWhenSelectionChanges() async throws {
        let recorder = ToolChangeRecorder()
        let session = try ChatKitSession(
            options: .init(
                api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit"))),
                events: .init(onToolChange: { toolID in
                    recorder.record(toolID)
                }),
            ),
            transport: RecordingTransport(),
        )

        await session.setComposerValue(selectedToolID: "search")
        await session.setComposerValue(text: "Prefilled message")
        await session.setComposerValue(selectedToolID: nil)

        XCTAssertEqual(recorder.recordedValues(), ["search", nil])
    }

    func testSendUserMessageEmitsToolChangeWhenNonPersistentToolIsCleared() async throws {
        let recorder = ToolChangeRecorder()
        let session = try ChatKitSession(
            options: .init(
                api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit"))),
                composer: .init(
                    tools: [.init(id: "search", label: "Search", icon: "magnifyingglass")],
                ),
                events: .init(onToolChange: { toolID in
                    recorder.record(toolID)
                }),
            ),
            transport: RecordingTransport(),
        )

        await session.setComposerValue(selectedToolID: "search")
        try await session.sendUserMessage(text: "Search this")

        XCTAssertEqual(recorder.recordedValues(), ["search", nil])
    }

    func testClientToolOutputRequestIncludesToolCallIdentifiers() async throws {
        let toolCall = ChatKitThreadItem.clientToolCall(.init(
            id: "tool_item_1",
            threadID: "thread_1",
            createdAt: Date(timeIntervalSince1970: 2),
            callID: "call_1",
            name: "lookup_order",
            arguments: ["order_id": .string("ord_123")],
        ))
        let transport = ClientToolOutputTransport(initialEvents: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init(),
            ))),
            .threadItemDone(.init(item: toolCall)),
        ])
        let session = try ChatKitSession(
            options: .init(
                api: .custom(url: XCTUnwrap(URL(string: "https://example.com/chatkit"))),
                onClientTool: { call in
                    XCTAssertEqual(call.name, "lookup_order")
                    XCTAssertEqual(call.params["order_id"], .string("ord_123"))
                    return ["ok": .bool(true)]
                },
            ),
            transport: transport,
        )

        try await session.sendUserMessage(text: "Check my order")

        let encodedRequests = try await transport.encodedStreamedRequestData().map { data in
            try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let outputRequest = try XCTUnwrap(encodedRequests.first { request in
            request["type"] as? String == "threads.add_client_tool_output"
        })
        let params = try XCTUnwrap(outputRequest["params"] as? [String: Any])

        XCTAssertEqual(params["thread_id"] as? String, "thread_1")
        XCTAssertEqual(params["item_id"] as? String, "tool_item_1")
        XCTAssertEqual(params["call_id"] as? String, "call_1")
    }
}

private final class ToolChangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String?] = []

    func record(_ value: String?) {
        lock.withLock {
            values.append(value)
        }
    }

    func recordedValues() -> [String?] {
        lock.withLock {
            values
        }
    }
}

private actor ClientToolOutputTransport: ChatKitTransport {
    var streamedRequests: [ChatKitRequest] = []
    let initialEvents: [ChatKitEvent]

    init(initialEvents: [ChatKitEvent]) {
        self.initialEvents = initialEvents
    }

    func send(_: ChatKitRequest) async throws -> Data {
        Data("{}".utf8)
    }

    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        streamedRequests.append(request)
        let events = request.type == "threads.add_client_tool_output" ? [] : initialEvents
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func encodedStreamedRequestData() throws -> [Data] {
        try streamedRequests.map { request in
            try ChatKitJSON.encoder.encode(request)
        }
    }
}

private actor RecordingTransport: ChatKitTransport {
    var streamedRequests: [ChatKitRequest] = []
    let events: [ChatKitEvent]
    let error: Error?

    init(events: [ChatKitEvent] = [], error: Error? = nil) {
        self.events = events
        self.error = error
    }

    func send(_: ChatKitRequest) async throws -> Data {
        Data("{}".utf8)
    }

    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        streamedRequests.append(request)
        if let error {
            throw error
        }
        let events = events
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func streamedRequestTypes() -> [String] {
        streamedRequests.map(\.type)
    }

    func encodedStreamedRequestData() throws -> [Data] {
        try streamedRequests.map { request in
            try ChatKitJSON.encoder.encode(request)
        }
    }
}

private struct ThreadLookupTransport: ChatKitTransport {
    let thread: ChatKitThread

    func send(_ request: ChatKitRequest) async throws -> Data {
        guard case .threadsGetByID = request else {
            throw ChatKitTransportError.invalidResponse
        }

        return try ChatKitJSON.encoder.encode(thread)
    }

    func stream(_: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private extension ChatKitConversationState {
    var userMessageTexts: [String] {
        items.compactMap { item in
            if case let .userMessage(message) = item {
                message.content.map(\.displayText).joined()
            } else {
                nil
            }
        }
    }
}
