@testable import ChatKitSwift
import XCTest

final class ChatKitSSEParserTests: XCTestCase {
    func testParserEmitsJSONPayloadsFromSplitDataFrames() {
        var parser = ChatKitSSEParser()

        let first = parser.append("data: {\"type\":\"progress_update\",")
        let second = parser.append("\"text\":\"Thinking\"}\n\n")

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, ["{\"type\":\"progress_update\",\"text\":\"Thinking\"}"])
    }

    func testParserIgnoresCommentsAndConcatenatesMultilineData() {
        var parser = ChatKitSSEParser()

        let events = parser.append("""
        : keep-alive
        data: {"type":"notice",
        data: "level":"info","message":"Saved"}

        """ + "\n")

        XCTAssertEqual(events, ["{\"type\":\"notice\",\n\"level\":\"info\",\"message\":\"Saved\"}"])
    }

    func testParserWaitsForBlankLineBeforeEmittingDataLine() {
        var parser = ChatKitSSEParser()

        let first = parser.append("data: {\"type\":\"thread.created\"}\n")
        let second = parser.append("\n")

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, ["{\"type\":\"thread.created\"}"])
    }

    func testParserFlushesRemainingFrameAtEndOfStream() {
        var parser = ChatKitSSEParser()

        let first = parser.append("data: {\"type\":\"stream_options\",\"stream_options\":{\"allow_cancel\":true}}")
        let second = parser.finish()

        XCTAssertEqual(first, [])
        XCTAssertEqual(second, ["{\"type\":\"stream_options\",\"stream_options\":{\"allow_cancel\":true}}"])
    }
}
