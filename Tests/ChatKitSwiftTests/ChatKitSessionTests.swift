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
}

private actor RecordingTransport: ChatKitTransport {
    var streamedRequests: [ChatKitRequest] = []
    let events: [ChatKitEvent]

    init(events: [ChatKitEvent]) {
        self.events = events
    }

    func send(_ request: ChatKitRequest) async throws -> Data {
        Data("{}".utf8)
    }

    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        streamedRequests.append(request)
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
