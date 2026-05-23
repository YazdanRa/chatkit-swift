import XCTest
@testable import ChatKitSwift

@MainActor
final class ChatKitSessionTests: XCTestCase {
    func testSendUserMessageCreatesThreadAndAppliesStream() async throws {
        let transport = RecordingTransport(events: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init()
            ))),
            .threadItemDone(.init(item: .assistantMessage(.init(
                id: "msg_1",
                threadID: "thread_1",
                createdAt: Date(timeIntervalSince1970: 2),
                content: [.init(text: "Hello")]
            )))),
        ])
        let session = ChatKitSession(
            options: .init(api: .custom(url: URL(string: "https://example.com/chatkit")!)),
            transport: transport
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
                items: .init()
            ))),
        ])
        let session = ChatKitSession(
            options: .init(api: .custom(url: URL(string: "https://example.com/chatkit")!)),
            transport: transport
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
            content: [.inputText(.init(text: "Hi"))]
        ))
        let transport = RecordingTransport(events: [
            .threadCreated(.init(thread: .init(
                title: "New",
                id: "thread_1",
                createdAt: Date(timeIntervalSince1970: 1),
                items: .init(data: [echoedMessage])
            ))),
        ])
        let session = ChatKitSession(
            options: .init(api: .custom(url: URL(string: "https://example.com/chatkit")!)),
            transport: transport
        )

        try await session.sendUserMessage(text: "Hi")

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(session.state.items.first?.id, "msg_user_1")
    }

    func testSendUserMessageKeepsUserMessageAndStoresReadableErrorWhenStreamFails() async throws {
        let errorPayload = Data(#"{"detail":"Invalid token"}"#.utf8)
        let transport = RecordingTransport(error: ChatKitTransportError.httpStatus(401, errorPayload))
        let session = ChatKitSession(
            options: .init(api: .custom(url: URL(string: "https://example.com/chatkit")!)),
            transport: transport
        )

        do {
            try await session.sendUserMessage(text: "Hi")
            XCTFail("Expected send to fail")
        } catch {}

        XCTAssertEqual(session.state.userMessageTexts, ["Hi"])
        XCTAssertEqual(session.state.error?.message, "HTTP 401: Invalid token")
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

    func send(_ request: ChatKitRequest) async throws -> Data {
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
