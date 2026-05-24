@testable import ChatKitSwift
import XCTest

final class ChatKitComposerControlsTests: XCTestCase {
    func testAttachmentsDoNotCreateComposerOptionsMenu() throws {
        let options = try ChatKitOptions(
            api: .custom(url: XCTUnwrap(URL(string: "https://example.com"))),
            composer: .init(attachments: .init(enabled: true)),
        )

        XCTAssertTrue(ChatKitComposerControls.showsAttachmentButton(for: options))
        XCTAssertFalse(ChatKitComposerControls.showsOptionsMenu(for: options))
    }

    func testToolsModelsAndEntitySearchCreateComposerOptionsMenu() throws {
        let options = try ChatKitOptions(
            api: .custom(url: XCTUnwrap(URL(string: "https://example.com"))),
            composer: .init(
                tools: [.init(id: "search", label: "Search", icon: "magnifyingglass")],
                models: [.init(id: "fast", label: "Fast")],
            ),
            entities: .init(onTagSearch: { _ in [] }, showComposerMenu: true),
        )

        XCTAssertFalse(ChatKitComposerControls.showsAttachmentButton(for: options))
        XCTAssertTrue(ChatKitComposerControls.showsOptionsMenu(for: options))
    }
}
