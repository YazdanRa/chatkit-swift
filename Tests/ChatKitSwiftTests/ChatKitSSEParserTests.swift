import XCTest
@testable import ChatKitSwift

final class ChatKitSSEParserTests: XCTestCase {
    func testParserEmitsJSONPayloadsFromSplitDataFrames() throws {
        var parser = ChatKitSSEParser()

        let first = parser.append("data: {\"type\":\"progress_update\",")
        let second = parser.append("\"text\":\"Thinking\"}\n\n")

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, ["{\"type\":\"progress_update\",\"text\":\"Thinking\"}"])
    }

    func testParserIgnoresCommentsAndConcatenatesMultilineData() throws {
        var parser = ChatKitSSEParser()

        let events = parser.append("""
        : keep-alive
        data: {"type":"notice",
        data: "level":"info","message":"Saved"}

        """)

        XCTAssertEqual(events, ["{\"type\":\"notice\",\n\"level\":\"info\",\"message\":\"Saved\"}"])
    }
}
