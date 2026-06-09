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

    func testWidgetCardDefaultsMatchReferencePalette() {
        XCTAssertEqual(ChatKitWidgetMetrics.defaultCardBackgroundHex(colorScheme: .light), "#FFFFFF")
        XCTAssertEqual(ChatKitWidgetMetrics.defaultCardBackgroundHex(colorScheme: .dark), "#282828")
        XCTAssertEqual(ChatKitWidgetMetrics.defaultCardBorderHex(colorScheme: .light), "#E3E3E3")
        XCTAssertEqual(ChatKitWidgetMetrics.defaultCardBorderHex(colorScheme: .dark), "#4F4F4F")
    }

    func testWidgetControlsUseReferenceFieldMetrics() {
        XCTAssertEqual(ChatKitWidgetMetrics.controlFieldHeight(nil), 32)
        XCTAssertEqual(ChatKitWidgetMetrics.controlFieldHeight("sm"), 28)
        XCTAssertEqual(ChatKitWidgetMetrics.textareaMinHeight(rows: 3), 72)
        XCTAssertEqual(ChatKitWidgetMetrics.selectionIndicatorSize, 16)
        XCTAssertEqual(ChatKitWidgetMetrics.checkboxIndicatorSize, 16)
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
            ChatKitWidgetMetrics.stackGap(.string("sm"), containerType: "Row", childTypes: ["Badge", "Badge"]),
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

    func testDecoratedBoxesFillAvailableWidthOutsideRows() {
        let box = ChatKitWidgetNode(type: "Box", raw: [
            "type": .string("Box"),
            "background": .string("#F3F4F6"),
        ])
        let plainBox = ChatKitWidgetNode(type: "Box", raw: ["type": .string("Box")])

        XCTAssertTrue(box.fillsAvailableWidth(parentType: "Card"))
        XCTAssertFalse(box.fillsAvailableWidth(parentType: "Row"))
        XCTAssertFalse(plainBox.fillsAvailableWidth(parentType: "Card"))
    }

    func testBoxPaddingDoesNotInventReferenceRendererInsets() {
        let box = ChatKitWidgetNode(type: "Box", raw: [
            "type": .string("Box"),
            "padding": .string("md"),
        ])
        let basic = ChatKitWidgetNode(type: "Basic", raw: [
            "type": .string("Basic"),
            "padding": .string("md"),
        ])

        XCTAssertEqual(box.containerInsets.top, 0)
        XCTAssertEqual(box.containerInsets.leading, 0)
        XCTAssertEqual(basic.containerInsets.top, 12)
        XCTAssertEqual(basic.containerInsets.leading, 12)
    }

    func testVerticalContainersMakeButtonsFillAvailableWidth() {
        let button = ChatKitWidgetNode(type: "Button", raw: [
            "type": .string("Button"),
            "label": .string("Open details"),
        ])
        let rowButton = ChatKitWidgetNode(type: "Button", raw: [
            "type": .string("Button"),
            "label": .string("Inline"),
        ])
        let explicitBlockButton = ChatKitWidgetNode(type: "Button", raw: [
            "type": .string("Button"),
            "label": .string("Block"),
            "block": .bool(true),
        ])

        XCTAssertTrue(button.buttonFillsAvailableWidth(parentType: "Card"))
        XCTAssertTrue(button.buttonFillsAvailableWidth(parentType: "Basic"))
        XCTAssertTrue(button.buttonFillsAvailableWidth(parentType: "Form"))
        XCTAssertTrue(button.buttonFillsAvailableWidth(parentType: "Col"))
        XCTAssertFalse(rowButton.buttonFillsAvailableWidth(parentType: "Row"))
        XCTAssertTrue(explicitBlockButton.buttonFillsAvailableWidth(parentType: "Row"))
    }

    func testRadioGroupDirectionFollowsWidgetContract() {
        let defaultRadio = ChatKitWidgetNode(type: "RadioGroup", raw: ["type": .string("RadioGroup")])
        let columnRadio = ChatKitWidgetNode(type: "RadioGroup", raw: [
            "type": .string("RadioGroup"),
            "direction": .string("col"),
        ])

        XCTAssertEqual(defaultRadio.widgetDirection(default: .row), .row)
        XCTAssertEqual(columnRadio.widgetDirection(default: .row), .col)
    }

    func testListLimitProducesNativeDisclosureSummary() {
        let list = ChatKitWidgetNode(type: "ListView", raw: [
            "type": .string("ListView"),
            "limit": .number(2),
            "children": .array([
                .object(["type": .string("ListViewItem"), "id": .string("first")]),
                .object(["type": .string("ListViewItem"), "id": .string("second")]),
                .object(["type": .string("ListViewItem"), "id": .string("third")]),
            ]),
        ])

        XCTAssertEqual(list.visibleListChildren(isExpanded: false).map(\.id), ["first", "second"])
        XCTAssertEqual(list.hiddenListChildCount, 1)
        XCTAssertEqual(list.hiddenListDisclosureLabel, "Show 1 more")
        XCTAssertEqual(list.visibleListChildren(isExpanded: true).map(\.id), ["first", "second", "third"])
    }

    func testRowsDetectPercentageWidthChildren() throws {
        let row = ChatKitWidgetNode(type: "Row", raw: [
            "type": .string("Row"),
            "children": .array([
                .object(["type": .string("Caption"), "value": .string("Direct")]),
                .object(["type": .string("Box"), "width": .string("72%"), "height": .number(8)]),
                .object(["type": .string("Caption"), "value": .string("42")]),
            ]),
        ])

        XCTAssertTrue(row.hasPercentageWidthChildren)
        let widthPercentage = try XCTUnwrap(row.children[1].widthPercentage)
        XCTAssertEqual(widthPercentage, CGFloat(0.72), accuracy: 0.001)
    }

    func testTransitionDecodesSingleChildObject() {
        let transition = ChatKitWidgetNode(type: "Transition", raw: [
            "type": .string("Transition"),
            "children": .object([
                "type": .string("Text"),
                "value": .string("Loaded"),
            ]),
        ])

        XCTAssertEqual(transition.children.map(\.type), ["Text"])
        XCTAssertEqual(transition.children.first?.value, "Loaded")
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
