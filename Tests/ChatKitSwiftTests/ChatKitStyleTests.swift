import XCTest
@testable import ChatKitSwift

final class ChatKitStyleTests: XCTestCase {
    func testDefaultThemeFollowsSystemColorScheme() {
        let theme = ChatKitTheme()

        XCTAssertEqual(theme.colorScheme, .system)
        XCTAssertNil(ChatKitStyle.preferredColorScheme(for: theme))
    }
}
