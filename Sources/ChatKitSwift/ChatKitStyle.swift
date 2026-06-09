import SwiftUI

enum ChatKitStyle {
    /// Resolves the chat surface background from theme surface colors.
    static func background(for theme: ChatKitTheme) -> Color {
        if let background = theme.color.surface?.background {
            return Color(hex: background) ?? .clear
        }
        switch theme.colorScheme {
        case .light:
            return .white
        case .dark:
            return .black
        case .system:
            return .clear
        }
    }

    /// Resolves the chat surface foreground from theme surface colors.
    static func foreground(for theme: ChatKitTheme) -> Color {
        if let foreground = theme.color.surface?.foreground {
            return Color(hex: foreground) ?? .primary
        }
        return .primary
    }

    /// Returns the explicit SwiftUI color scheme requested by the theme.
    static func preferredColorScheme(for theme: ChatKitTheme) -> SwiftUI.ColorScheme? {
        switch theme.colorScheme {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            nil
        }
    }

    /// Maps backend or configuration icon names to SF Symbols.
    ///
    /// The renderer accepts plain SF Symbol names, common ChatKit icon aliases, and
    /// `lucide:`-prefixed names. Unknown values pass through unchanged so hosts can
    /// use native symbols without waiting for a mapping update.
    static func systemImage(for icon: String) -> String {
        let normalized = icon.replacing("lucide:", with: "")
        return iconMap[normalized] ?? normalized
    }

    private static let iconMap = [
        "agent": "sparkles",
        "analytics": "chart.bar",
        "arrow-up-right": "arrow.up.right",
        "arrow.right": "arrow.right",
        "arrow.up": "arrow.up",
        "atom": "atom",
        "badge-check": "checkmark.seal",
        "batch": "square.stack.3d.up",
        "bolt": "bolt",
        "book-open": "book",
        "book-closed": "book.closed",
        "book-clock": "clock",
        "bug": "ladybug",
        "calendar": "calendar",
        "chart": "chart.bar",
        "chart.bar": "chart.bar",
        "check": "checkmark",
        "check-circle": "checkmark.circle",
        "checkmark.circle": "checkmark.circle",
        "check-circle-filled": "checkmark.circle.fill",
        "chevron-left": "chevron.left",
        "chevron-right": "chevron.right",
        "circle-alert": "exclamationmark.circle",
        "circle-question": "questionmark.circle",
        "clock": "clock",
        "compass": "safari",
        "confetti": "party.popper",
        "cube": "cube",
        "desktop": "desktopcomputer",
        "document": "doc.text",
        "square-text": "doc.text",
        "page-blank": "doc",
        "dot": "circle.fill",
        "empty-circle": "circle",
        "dots-horizontal": "ellipsis",
        "dots-vertical": "ellipsis.vertical",
        "external-link": "arrow.up.right.square",
        "globe": "globe",
        "keys": "key",
        "lab": "flask",
        "images": "photo",
        "square-image": "photo.on.rectangle",
        "exclamationmark.triangle": "exclamationmark.triangle",
        "info": "info.circle",
        "info.circle": "info.circle",
        "lifesaver": "lifepreserver",
        "lightbulb": "lightbulb",
        "line.3.horizontal": "line.3.horizontal",
        "mail": "envelope",
        "map-pin": "mappin",
        "maps": "map",
        "mobile": "iphone",
        "phone": "phone",
        "name": "character.cursor.ibeam",
        "notebook": "note.text",
        "notebook-pencil": "note.text",
        "play": "play.fill",
        "plus": "plus",
        "profile": "person.crop.circle",
        "profile-card": "person.text.rectangle",
        "user": "person",
        "reload": "arrow.clockwise",
        "star": "star",
        "star-filled": "star.fill",
        "search": "magnifyingglass",
        "sparkle": "sparkles",
        "sparkle-double": "sparkles",
        "square-code": "chevron.left.forwardslash.chevron.right",
        "suitcase": "briefcase",
        "settings-slider": "slider.horizontal.3",
        "settings-cog": "slider.horizontal.3",
        "wreath": "rosette",
        "write": "square.and.pencil",
        "compose": "square.and.pencil",
        "square.and.pencil": "square.and.pencil",
        "write-alt": "pencil",
        "write-alt2": "pencil.and.outline",
        "pencil": "pencil",
        "sidebar-left": "sidebar.left",
        "sidebar-open-left": "sidebar.left",
        "history": "sidebar.left",
        "sidebar.left": "sidebar.left",
        "sidebar-right": "sidebar.right",
        "sidebar-open-right": "sidebar.right",
        "sidebar.right": "sidebar.right",
        "close": "xmark",
        "circle.dashed": "circle.dashed",
        "home": "house",
        "home-alt": "house",
        "share": "square.and.arrow.up",
        "dark-mode": "moon",
        "light-mode": "sun.max",
    ]
}

private extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6 || value.count == 8,
              let integer = UInt64(value, radix: 16)
        else {
            return nil
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if value.count == 8 {
            red = Double((integer & 0xFF00_0000) >> 24) / 255
            green = Double((integer & 0x00FF_0000) >> 16) / 255
            blue = Double((integer & 0x0000_FF00) >> 8) / 255
            alpha = Double(integer & 0x0000_00FF) / 255
        } else {
            red = Double((integer & 0xFF0000) >> 16) / 255
            green = Double((integer & 0x00FF00) >> 8) / 255
            blue = Double(integer & 0x0000FF) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
