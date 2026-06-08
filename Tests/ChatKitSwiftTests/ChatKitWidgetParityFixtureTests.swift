@testable import ChatKitSwift
import XCTest

final class ChatKitWidgetParityFixtureTests: XCTestCase {
    func testWidgetParityManifestIsValid() throws {
        let manifest = try Self.loadManifest()

        XCTAssertEqual(manifest.version, 1)
        XCTAssertGreaterThanOrEqual(manifest.fixtures.count, 5)

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
    }

    private static func loadManifest() throws -> WidgetParityManifest {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "WidgetParity/fixtures/widgets.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetParityManifest.self, from: data)
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
