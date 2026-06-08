@testable import ChatKitSwift
import XCTest

final class ChatKitWidgetTemplateTests: XCTestCase {
    @MainActor
    func testWidgetPreviewCanBeConstructedFromGeneratedNode() {
        let widget = ChatKitWidgetNode(type: "Card", raw: [
            "type": .string("Card"),
            "children": .array([
                .object(["type": .string("Title"), "value": .string("Preview")]),
            ]),
        ])

        let preview = ChatKitWidgetPreview(widget: widget)

        XCTAssertEqual(String(describing: type(of: preview)), "ChatKitWidgetPreview")
    }

    func testRendersStudioTemplateWithJSONStateValues() throws {
        let template = """
        {
          "type": "Card",
          "children": [
            { "type": "Title", "id": "title", "value": {{ (title) | tojson }} },
            { "type": "Badge", "id": "status", "label": {{ (statusLabel) | tojson }}, "color": {{ (statusColor) | tojson }} },
            { "type": "Box", "id": "progress", "width": {{ (progressWidth) | tojson }} }
          ]
        }
        """
        let widget = try ChatKitWidgetTemplate(
            template: template,
            state: [
                "title": .string("Website Revamp"),
                "statusLabel": .string("On track"),
                "statusColor": .string("success"),
                "progressWidth": .string("68%"),
            ],
        ).renderNode()

        XCTAssertEqual(widget.type, "Card")
        XCTAssertEqual(widget.children[0].raw["value"], .string("Website Revamp"))
        XCTAssertEqual(widget.children[1].raw["label"], .string("On track"))
        XCTAssertEqual(widget.children[1].raw["color"], .string("success"))
        XCTAssertEqual(widget.children[2].raw["width"], .string("68%"))
    }

    func testThrowsWhenTemplateReferencesMissingStateValue() {
        let template = #"{ "type": "Title", "value": {{ (title) | tojson }} }"#

        XCTAssertThrowsError(try ChatKitWidgetTemplate(template: template, state: [:]).renderNode()) { error in
            XCTAssertEqual(error as? ChatKitWidgetTemplateError, .missingStateValue("title"))
        }
    }
}
