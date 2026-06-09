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

    func testOpenAIWidgetIconsMapToNativeSymbols() {
        let mappings = [
            "agent": "sparkles",
            "analytics": "chart.bar",
            "atom": "atom",
            "batch": "square.stack.3d.up",
            "bolt": "bolt",
            "book-open": "book",
            "book-closed": "book.closed",
            "book-clock": "clock",
            "bug": "ladybug",
            "calendar": "calendar",
            "chart": "chart.bar",
            "check": "checkmark",
            "check-circle": "checkmark.circle",
            "check-circle-filled": "checkmark.circle.fill",
            "chevron-left": "chevron.left",
            "chevron-right": "chevron.right",
            "circle-question": "questionmark.circle",
            "clock": "clock",
            "compass": "safari",
            "confetti": "party.popper",
            "cube": "cube",
            "desktop": "desktopcomputer",
            "document": "doc.text",
            "dot": "circle.fill",
            "dots-horizontal": "ellipsis",
            "dots-vertical": "ellipsis.vertical",
            "empty-circle": "circle",
            "external-link": "arrow.up.right.square",
            "globe": "globe",
            "keys": "key",
            "lab": "flask",
            "images": "photo",
            "info": "info.circle",
            "lifesaver": "lifepreserver",
            "lightbulb": "lightbulb",
            "mail": "envelope",
            "map-pin": "mappin",
            "maps": "map",
            "mobile": "iphone",
            "name": "character.cursor.ibeam",
            "notebook": "note.text",
            "notebook-pencil": "note.text",
            "page-blank": "doc",
            "phone": "phone",
            "play": "play.fill",
            "plus": "plus",
            "profile": "person.crop.circle",
            "profile-card": "person.text.rectangle",
            "reload": "arrow.clockwise",
            "star": "star",
            "star-filled": "star.fill",
            "search": "magnifyingglass",
            "sparkle": "sparkles",
            "sparkle-double": "sparkles",
            "square-code": "chevron.left.forwardslash.chevron.right",
            "square-image": "photo.on.rectangle",
            "square-text": "doc.text",
            "suitcase": "briefcase",
            "settings-slider": "slider.horizontal.3",
            "user": "person",
            "wreath": "rosette",
            "write": "square.and.pencil",
            "write-alt": "pencil",
            "write-alt2": "pencil.and.outline",
        ]

        for (openAIIcon, systemImage) in mappings {
            XCTAssertEqual(ChatKitStyle.systemImage(for: openAIIcon), systemImage, openAIIcon)
        }
    }

    func testLucideIconNamesNormalizeToSFSymbolFallbacks() {
        XCTAssertEqual(ChatKitStyle.systemImage(for: "lucide:circle-alert"), "exclamationmark.circle")
        XCTAssertEqual(ChatKitStyle.systemImage(for: "lucide:arrow-up-right"), "arrow.up.right")
        XCTAssertEqual(ChatKitStyle.systemImage(for: "lucide:badge-check"), "checkmark.seal")
    }
}
