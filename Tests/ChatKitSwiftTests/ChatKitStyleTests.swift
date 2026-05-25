@testable import ChatKitSwift
import XCTest

final class ChatKitStyleTests: XCTestCase {
    func testDefaultThemeFollowsSystemColorScheme() {
        let theme = ChatKitTheme()

        XCTAssertEqual(theme.colorScheme, .system)
        XCTAssertNil(ChatKitStyle.preferredColorScheme(for: theme))
    }

    func testDirectSFSymbolNamesPassThrough() {
        XCTAssertEqual(ChatKitStyle.systemImage(for: "slider.horizontal.3"), "slider.horizontal.3")
        XCTAssertEqual(ChatKitStyle.systemImage(for: "paintpalette"), "paintpalette")
    }
}
