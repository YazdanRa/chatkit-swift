import SwiftUI

enum ChatKitStyle {
    static func background(for theme: ChatKitTheme) -> Color {
        if let background = theme.color.surface?.background {
            return Color(hex: background) ?? .clear
        }
        return theme.colorScheme == .dark ? .black : .clear
    }

    static func foreground(for theme: ChatKitTheme) -> Color {
        if let foreground = theme.color.surface?.foreground {
            return Color(hex: foreground) ?? .primary
        }
        return .primary
    }

    static func systemImage(for icon: String) -> String {
        let normalized = icon.replacing("lucide:", with: "")
        return switch normalized {
        case "agent": "sparkles"
        case "analytics", "chart": "chart.bar"
        case "atom": "atom"
        case "batch": "square.stack.3d.up"
        case "bolt": "bolt"
        case "book-open": "book"
        case "book-closed": "book.closed"
        case "book-clock": "clock"
        case "bug": "ladybug"
        case "calendar": "calendar"
        case "check", "check-circle", "check-circle-filled": "checkmark.circle"
        case "chevron-left": "chevron.left"
        case "chevron-right": "chevron.right"
        case "circle-question": "questionmark.circle"
        case "clock": "clock"
        case "compass": "safari"
        case "confetti": "party.popper"
        case "cube": "cube"
        case "desktop": "desktopcomputer"
        case "document", "page-blank", "square-text": "doc.text"
        case "dot", "empty-circle": "circle"
        case "dots-horizontal": "ellipsis"
        case "dots-vertical": "ellipsis"
        case "external-link": "arrow.up.right.square"
        case "globe": "globe"
        case "keys": "key"
        case "lab": "flask"
        case "images", "square-image": "photo"
        case "info": "info.circle"
        case "lifesaver": "questionmark.life.ar"
        case "lightbulb": "lightbulb"
        case "mail": "envelope"
        case "map-pin", "maps": "mappin"
        case "mobile", "phone": "iphone"
        case "name": "character.cursor.ibeam"
        case "notebook", "notebook-pencil": "note.text"
        case "play": "play"
        case "plus": "plus"
        case "profile", "profile-card", "user": "person.crop.circle"
        case "reload": "arrow.clockwise"
        case "star", "star-filled": "star"
        case "search": "magnifyingglass"
        case "sparkle", "sparkle-double": "sparkles"
        case "square-code": "chevron.left.forwardslash.chevron.right"
        case "suitcase": "briefcase"
        case "settings-slider", "settings-cog": "slider.horizontal.3"
        case "write", "write-alt", "write-alt2", "compose": "square.and.pencil"
        case "sidebar-left", "sidebar-open-left", "history": "sidebar.left"
        case "sidebar-right", "sidebar-open-right": "sidebar.right"
        case "close": "xmark"
        case "home", "home-alt": "house"
        case "share": "square.and.arrow.up"
        case "dark-mode": "moon"
        case "light-mode": "sun.max"
        default: normalized
        }
    }
}

private extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6 || value.count == 8,
              let integer = UInt64(value, radix: 16) else {
            return nil
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if value.count == 8 {
            red = Double((integer & 0xff00_0000) >> 24) / 255
            green = Double((integer & 0x00ff_0000) >> 16) / 255
            blue = Double((integer & 0x0000_ff00) >> 8) / 255
            alpha = Double(integer & 0x0000_00ff) / 255
        } else {
            red = Double((integer & 0xff0000) >> 16) / 255
            green = Double((integer & 0x00ff00) >> 8) / 255
            blue = Double(integer & 0x0000ff) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
