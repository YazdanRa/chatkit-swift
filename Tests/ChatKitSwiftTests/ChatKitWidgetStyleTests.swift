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

    func testDimensionsParseNumbersPixelsAndPercentages() throws {
        XCTAssertEqual(ChatKitWidgetMetrics.fixedDimension(.number(8)), 8)
        XCTAssertEqual(ChatKitWidgetMetrics.fixedDimension(.string("12px")), 12)
        XCTAssertNil(ChatKitWidgetMetrics.fixedDimension(.string("68%")))
        let percentage = try XCTUnwrap(ChatKitWidgetMetrics.percentage(.string("68%")))
        XCTAssertEqual(percentage, CGFloat(0.68), accuracy: 0.001)
        XCTAssertNil(ChatKitWidgetMetrics.percentage(.string("auto")))
    }

    func testSemanticWidgetColorsResolveNativePalettes() {
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "primary"), .primary)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "caution"), .warning)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "danger"), .danger)
        XCTAssertEqual(ChatKitWidgetTone(rawValue: "discovery"), .discovery)
    }

    func testWidgetTypographyMatchesReferenceTokenScale() {
        XCTAssertEqual(ChatKitWidgetMetrics.titlePointSize("sm"), 18)
        XCTAssertEqual(ChatKitWidgetMetrics.titleLineHeight("sm"), 26)
        XCTAssertEqual(ChatKitWidgetMetrics.titlePointSize("lg"), 24)
        XCTAssertEqual(ChatKitWidgetMetrics.titleLineHeight("lg"), 28)

        XCTAssertEqual(ChatKitWidgetMetrics.textPointSize("md"), 16)
        XCTAssertEqual(ChatKitWidgetMetrics.textLineHeight("md"), 24)
        XCTAssertEqual(ChatKitWidgetMetrics.additionalLineSpacing(pointSize: 16, lineHeight: 24), 4)
        XCTAssertEqual(ChatKitWidgetMetrics.captionPointSize(nil), 12)
        XCTAssertEqual(ChatKitWidgetMetrics.captionLineHeight(nil), 15.6, accuracy: 0.01)
        XCTAssertEqual(ChatKitWidgetMetrics.additionalLineSpacing(pointSize: 12, lineHeight: 15.6), 0)
    }

    func testWidgetButtonsDefaultToReferenceLargePillMetrics() {
        XCTAssertEqual(ChatKitWidgetMetrics.buttonHeight(nil), 36)
        XCTAssertEqual(ChatKitWidgetMetrics.buttonFontPointSize(nil), 14)
        XCTAssertEqual(ChatKitWidgetMetrics.buttonHorizontalPadding(nil, pill: true), 15.96, accuracy: 0.01)
        XCTAssertEqual(ChatKitWidgetMetrics.buttonCornerRadius(nil, pill: false), 999)
    }

    func testWidgetToneReferencePaletteMatchesChatKitJS() {
        XCTAssertEqual(ChatKitWidgetTone.primary.solidHex, "#181818")
        XCTAssertEqual(ChatKitWidgetTone.secondary.softHex, "#EDEDED")
        XCTAssertEqual(ChatKitWidgetTone.info.accentHex, "#0169CC")
        XCTAssertEqual(ChatKitWidgetTone.success.accentHex, "#008635")
        XCTAssertEqual(ChatKitWidgetTone.danger.accentHex, "#E02E2A")
    }

    func testWidgetStackGapCollapsesForFlushReferenceRows() {
        XCTAssertEqual(
            ChatKitWidgetMetrics.stackGap(.string("sm"), containerType: "Col", childTypes: ["Button", "Button"]),
            0,
        )
        XCTAssertEqual(
            ChatKitWidgetMetrics.stackGap(.string("sm"), containerType: "Row", childTypes: ["Box", "Box"]),
            0,
        )
        XCTAssertEqual(
            ChatKitWidgetMetrics.stackGap(.string("sm"), containerType: "Col", childTypes: ["Text", "Button"]),
            8,
        )
        XCTAssertEqual(
            ChatKitWidgetMetrics.stackGap(.number(8), containerType: "Col", childTypes: ["Button", "Button"]),
            8,
        )
    }

    func testStudioColorTokensResolveToNativeColors() {
        XCTAssertNotNil(ChatKitWidgetColor.color("tertiary"))
        XCTAssertNotNil(ChatKitWidgetColor.color("surface-tertiary"))
        XCTAssertNotNil(ChatKitWidgetColor.color("green-500"))
        XCTAssertNotNil(ChatKitWidgetColor.color("red-500"))
        XCTAssertNotNil(ChatKitWidgetColor.color("blue-500"))
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
