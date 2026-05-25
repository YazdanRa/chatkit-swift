@testable import ChatKitSwift
import XCTest

final class ChatKitWidgetStyleTests: XCTestCase {
    func testSpacingParsesNumbersPixelsAndNamedTokens() {
        XCTAssertEqual(ChatKitWidgetMetrics.spacing(.number(7)), 7)
        XCTAssertEqual(ChatKitWidgetMetrics.spacing(.string("12px")), 12)
        XCTAssertEqual(ChatKitWidgetMetrics.spacing(.string("md")), 12)
        XCTAssertEqual(ChatKitWidgetMetrics.spacing(.string("2xl")), 24)
        XCTAssertNil(ChatKitWidgetMetrics.spacing(.string("auto")))
    }

    func testInsetsPreferAxisValuesThenSideValues() {
        let value = JSONValue.object([
            "x": .number(10),
            "y": .string("sm"),
            "top": .number(2),
        ])

        let insets = ChatKitWidgetMetrics.insets(value, fallback: 4)

        XCTAssertEqual(insets.top, 2)
        XCTAssertEqual(insets.bottom, 8)
        XCTAssertEqual(insets.leading, 10)
        XCTAssertEqual(insets.trailing, 10)
    }

    func testRadiusTokensTranslateToNativeCornerRadii() {
        XCTAssertEqual(ChatKitWidgetMetrics.radius(.string("none")), 0)
        XCTAssertEqual(ChatKitWidgetMetrics.radius(.string("md")), 10)
        XCTAssertEqual(ChatKitWidgetMetrics.radius(.string("full")), 999)
        XCTAssertEqual(ChatKitWidgetMetrics.radius(.number(14)), 14)
    }

    func testSemanticWidgetColorsResolveNativePalettes() {
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "primary"), .primary)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "caution"), .warning)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "danger"), .danger)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "discovery"), .discovery)
    }

    func testChartDataExtractsLabelsValuesAndColors() {
        let node = ChatKitWidgetNode(type: "Chart", raw: [
            "type": .string("Chart"),
            "data": .array([
                .object(["label": .string("Open"), "value": .number(4), "color": .string("success")]),
                .object(["label": .string("Closed"), "value": .number(10), "color": .string("#FF0000")]),
            ]),
        ])

        let points = ChatKitWidgetChartPoint.points(in: node)

        XCTAssertEqual(points.map(\.label), ["Open", "Closed"])
        XCTAssertEqual(points.map(\.value), [4, 10])
        XCTAssertEqual(points.map(\.colorToken), ["success", "#FF0000"])
    }
}
