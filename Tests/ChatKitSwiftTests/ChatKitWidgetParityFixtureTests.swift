@testable import ChatKitSwift
import XCTest

final class ChatKitWidgetParityFixtureTests: XCTestCase {
    func testWidgetParityManifestIsValid() throws {
        let manifest = try Self.loadManifest()

        XCTAssertEqual(manifest.version, 1)
        XCTAssertGreaterThanOrEqual(manifest.fixtures.count, 30)

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
            "Transition",
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
        XCTAssertTrue(script.contains("Compare Swift to JS directly before considering the diff heatmap."))
        XCTAssertTrue(script.contains("Pixel metrics are advisory."))
        XCTAssertTrue(script.contains("A passing pixel check does not automatically mean pass"))
        XCTAssertTrue(script.contains("confidence"))
        XCTAssertTrue(script.contains("ignored_differences"))
        XCTAssertFalse(script.contains("recommendedFixes"))
        XCTAssertTrue(script.contains("visualReviewCounts"))
        XCTAssertTrue(script.contains("pixelFailuresAreBlocking"))
        XCTAssertTrue(script.contains("!options.visualReview && failed.length > 0"))
        XCTAssertTrue(script.contains("pass, ${counts.review} review, ${counts.fail} fail"))
        XCTAssertTrue(script.contains("Failed JS capture"))
        XCTAssertTrue(script.contains("jsError"))
    }

    func testWidgetParityScriptHandlesSingleObjectChildren() throws {
        let script = try String(contentsOf: Self.repoRoot().appending(path: "scripts/widget-parity.js"), encoding: .utf8)

        XCTAssertTrue(script.contains("function widgetChildren(node)"))
        XCTAssertTrue(script.contains("Array.isArray(node.children)"))
        XCTAssertTrue(script.contains("typeof node.children === \"object\""))
        XCTAssertTrue(script.contains("for (const child of widgetChildren(node))"))
    }

    func testGeneratedWidgetFuzzHarnessUsesRealStudioCorpus() throws {
        let script = try String(contentsOf: Self.repoRoot().appending(path: "scripts/widget-fuzz.js"), encoding: .utf8)
        let promptCorpus = try Self.loadGeneratedPromptCorpus()
        let generatedManifest = try Self.loadGeneratedWidgetManifest()

        XCTAssertEqual(promptCorpus.version, 1)
        XCTAssertGreaterThanOrEqual(promptCorpus.prompts.count, 100)
        XCTAssertLessThanOrEqual(promptCorpus.prompts.count, 300)
        XCTAssertEqual(Set(promptCorpus.prompts.map(\.id)).count, promptCorpus.prompts.count)
        XCTAssertTrue(promptCorpus.prompts.allSatisfy { !$0.prompt.isEmpty })
        XCTAssertEqual(generatedManifest.version, 1)
        XCTAssertGreaterThanOrEqual(generatedManifest.fixtures.count, 100)
        XCTAssertLessThanOrEqual(generatedManifest.fixtures.count, 300)
        XCTAssertEqual(Set(generatedManifest.fixtures.map(\.id)).count, generatedManifest.fixtures.count)
        XCTAssertTrue(generatedManifest.failures.isEmpty)
        XCTAssertTrue(script.contains("https://widgets.chatkit.studio/create-widget"))
        XCTAssertTrue(script.contains("https://widgets.chatkit.studio/convert-widget-to-file"))
        XCTAssertTrue(script.contains("DEFAULT_COUNT = 100"))
        XCTAssertTrue(script.contains("MAX_COUNT = 300"))
        XCTAssertTrue(script.contains("DEFAULT_RETRIES = 2"))
        XCTAssertTrue(script.contains("NUNJUCKS_VERSION = \"3.2.4\""))
        XCTAssertTrue(script.contains("UNDEFINED_SENTINEL"))
        XCTAssertTrue(script.contains("renderTemplate"))
        XCTAssertTrue(script.contains("normalizeWidget"))
        XCTAssertTrue(script.contains("key === \"key\""))
        XCTAssertTrue(script.contains("child === UNDEFINED_SENTINEL"))
        XCTAssertTrue(script.contains("normalizeStudioTemplate"))
        XCTAssertTrue(script.contains("trimLeadingComma"))
        XCTAssertTrue(script.contains("retryPromptIds"))
        XCTAssertTrue(script.contains("unsupported state interpolation syntax"))
        XCTAssertTrue(script.contains("WidgetParity/fixtures/generated-widgets.json"))
        XCTAssertTrue(script.contains("--run-parity"))
        XCTAssertFalse(script.contains("OPENAI_API_KEY"))
    }

    private static func loadManifest() throws -> WidgetParityManifest {
        let url = repoRoot()
            .appending(path: "WidgetParity/fixtures/widgets.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetParityManifest.self, from: data)
    }

    private static func loadGeneratedPromptCorpus() throws -> WidgetFuzzPromptCorpus {
        let url = repoRoot()
            .appending(path: "WidgetParity/prompts/generated-widget-prompts.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetFuzzPromptCorpus.self, from: data)
    }

    private static func loadGeneratedWidgetManifest() throws -> GeneratedWidgetFuzzManifest {
        let url = repoRoot()
            .appending(path: "WidgetParity/fixtures/generated-widgets.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GeneratedWidgetFuzzManifest.self, from: data)
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

private struct WidgetFuzzPromptCorpus: Decodable {
    var version: Int
    var prompts: [WidgetFuzzPrompt]
}

private struct WidgetFuzzPrompt: Decodable {
    var id: String
    var prompt: String
}

private struct GeneratedWidgetFuzzManifest: Decodable {
    var version: Int
    var fixtures: [GeneratedWidgetFuzzFixture]
    var failures: [GeneratedWidgetFuzzFailure]
}

private struct GeneratedWidgetFuzzFixture: Decodable {
    var id: String
}

private struct GeneratedWidgetFuzzFailure: Decodable {}
