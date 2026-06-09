@testable import ChatKitSwift
import XCTest

final class ChatKitWidgetParityFixtureTests: XCTestCase {
    func testWidgetParityManifestIsValid() throws {
        let manifest = try Self.loadManifest()

        XCTAssertEqual(manifest.version, 1)
        XCTAssertGreaterThanOrEqual(manifest.fixtures.count, 10)

        let ids = manifest.fixtures.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Fixture identifiers must be unique.")

        let validRootTypes: Set<String> = ["Basic", "Card", "ListView"]
        let validThemes: Set<String> = ["light", "dark"]
        for fixture in manifest.fixtures {
            XCTAssertFalse(fixture.id.isEmpty)
            XCTAssertFalse(fixture.name.isEmpty)
            XCTAssertTrue(validThemes.contains(fixture.theme), "\(fixture.id) must declare light or dark theme.")
            XCTAssertTrue(validRootTypes.contains(fixture.widget.type), "\(fixture.id) must use an official ChatKit widget root.")
            XCTAssertGreaterThanOrEqual(fixture.viewport.width, 240)
            XCTAssertGreaterThanOrEqual(fixture.viewport.height, 240)
            XCTAssertGreaterThanOrEqual(fixture.threshold, 0)
            XCTAssertLessThan(fixture.threshold, 1)
        }

        let componentTypes = Set(manifest.fixtures.flatMap { Self.componentTypes(in: $0.widget) })
        let requiredComponentTypes: Set<String> = [
            "Badge",
            "Basic",
            "Box",
            "Button",
            "Caption",
            "Card",
            "Checkbox",
            "Col",
            "DatePicker",
            "Divider",
            "Form",
            "Icon",
            "Input",
            "Label",
            "ListView",
            "ListViewItem",
            "Markdown",
            "RadioGroup",
            "Row",
            "Select",
            "Spacer",
            "Table",
            "Table.Cell",
            "Table.Row",
            "Text",
            "Textarea",
            "Title",
        ]
        XCTAssertTrue(
            requiredComponentTypes.isSubset(of: componentTypes),
            "Missing fixture coverage for: \(requiredComponentTypes.subtracting(componentTypes).sorted().joined(separator: ", "))",
        )
    }

    func testWidgetParityScriptSupportsVisualReview() throws {
        let script = try String(contentsOf: Self.repoRoot().appending(path: "scripts/widget-parity.js"), encoding: .utf8)

        XCTAssertTrue(script.contains("--visual-review"))
        XCTAssertTrue(script.contains("OPENAI_API_KEY"))
        XCTAssertTrue(script.contains("/v1/responses"))
        XCTAssertTrue(script.contains("gpt-5.4-mini-2026-03-17"))
        XCTAssertTrue(script.contains("VISUAL_REVIEW_RESPONSE_FORMAT"))
        XCTAssertTrue(script.contains("json_schema"))
        XCTAssertTrue(script.contains("visualDetail: \"auto\""))
        XCTAssertTrue(script.contains("reasoning: { effort: \"low\" }"))
    }

    private static func loadManifest() throws -> WidgetParityManifest {
        let url = repoRoot()
            .appending(path: "WidgetParity/fixtures/widgets.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetParityManifest.self, from: data)
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func componentTypes(in node: ChatKitWidgetNode) -> [String] {
        [node.type] + node.children.flatMap(componentTypes(in:))
    }
}

private struct WidgetParityManifest: Decodable {
    var version: Int
    var fixtures: [WidgetParityFixture]
}

private struct WidgetParityFixture: Decodable {
    var id: String
    var name: String
    var theme: String
    var viewport: WidgetParityViewport
    var threshold: Double
    var widget: ChatKitWidgetNode
}

private struct WidgetParityViewport: Decodable {
    var width: Int
    var height: Int
}
