import Foundation
import SwiftUI

/// Semantic widget tone used to translate backend color tokens into SwiftUI colors.
enum ChatKitWidgetTone: Equatable {
    case primary
    case secondary
    case info
    case discovery
    case success
    case warning
    case danger

    init?(rawValue: String) {
        switch rawValue {
        case "primary":
            self = .primary
        case "secondary":
            self = .secondary
        case "info":
            self = .info
        case "discovery":
            self = .discovery
        case "success":
            self = .success
        case "caution", "warning":
            self = .warning
        case "danger":
            self = .danger
        default:
            return nil
        }
    }

    /// Foreground color for solid controls and badges.
    var foreground: Color {
        switch self {
        case .primary, .discovery, .success, .warning, .danger:
            .white
        case .secondary, .info:
            .primary
        }
    }

    /// Background color for solid controls and badges.
    var solidBackground: Color {
        switch self {
        case .primary:
            .accentColor
        case .secondary:
            .secondary.opacity(0.18)
        case .info:
            .blue
        case .discovery:
            .purple
        case .success:
            .green
        case .warning:
            .orange
        case .danger:
            .red
        }
    }

    /// Low-emphasis background color for outline and soft widget treatments.
    var softBackground: Color {
        solidBackground.opacity(0.16)
    }

    /// Low-emphasis foreground color for outline and soft widget treatments.
    var softForeground: Color {
        switch self {
        case .primary:
            .accentColor
        case .secondary:
            .secondary
        case .info:
            .blue
        case .discovery:
            .purple
        case .success:
            .green
        case .warning:
            .orange
        case .danger:
            .red
        }
    }
}

/// Converts backend widget size tokens into SwiftUI layout values.
enum ChatKitWidgetMetrics {
    /// Resolves a JSON spacing token or numeric value into points.
    static func spacing(_ value: JSONValue?) -> CGFloat? {
        switch value {
        case let .number(number):
            CGFloat(number)
        case let .string(string):
            spacing(string)
        default:
            nil
        }
    }

    /// Resolves named spacing tokens, pixel strings, and numeric strings.
    static func spacing(_ token: String) -> CGFloat? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("px") {
            return Double(trimmed.dropLast(2)).map { CGFloat($0) }
        }
        if let number = Double(trimmed) {
            return CGFloat(number)
        }
        return switch trimmed {
        case "3xs": 2
        case "2xs": 4
        case "xs": 6
        case "sm": 8
        case "md": 12
        case "lg": 16
        case "xl": 20
        case "2xl": 24
        case "3xl": 32
        case "4xl": 40
        default: nil
        }
    }

    /// Resolves fixed dimensions from numeric values, pixel strings, and numeric strings.
    static func fixedDimension(_ value: JSONValue?) -> CGFloat? {
        switch value {
        case let .number(number):
            CGFloat(number)
        case let .string(string):
            fixedDimension(string)
        default:
            nil
        }
    }

    /// Resolves percentage strings such as `"68%"` into unit fractions.
    static func percentage(_ value: JSONValue?) -> CGFloat? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("%"),
              let number = Double(trimmed.dropLast())
        else {
            return nil
        }
        return CGFloat(number / 100)
    }

    private static func fixedDimension(_ token: String) -> CGFloat? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%") {
            return nil
        }
        if trimmed.hasSuffix("px") {
            return Double(trimmed.dropLast(2)).map { CGFloat($0) }
        }
        return Double(trimmed).map { CGFloat($0) }
    }

    /// Resolves scalar or directional padding objects into edge insets.
    static func insets(_ value: JSONValue?, fallback: CGFloat = 0) -> EdgeInsets {
        guard case let .object(object)? = value else {
            let spacing = spacing(value) ?? fallback
            return EdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
        }

        let horizontal = spacing(object["x"])
        let vertical = spacing(object["y"])
        return EdgeInsets(
            top: spacing(object["top"]) ?? vertical ?? fallback,
            leading: spacing(object["left"]) ?? horizontal ?? fallback,
            bottom: spacing(object["bottom"]) ?? vertical ?? fallback,
            trailing: spacing(object["right"]) ?? horizontal ?? fallback,
        )
    }

    /// Resolves backend radius tokens into SwiftUI corner radii.
    static func radius(_ value: JSONValue?) -> CGFloat {
        switch value {
        case let .number(number):
            return CGFloat(number)
        case let .string(token):
            if let number = Double(token) {
                return CGFloat(number)
            }
            return switch token {
            case "none": 0
            case "2xs": 2
            case "xs": 4
            case "sm": 6
            case "md": 10
            case "lg": 12
            case "xl": 16
            case "2xl": 20
            case "3xl": 24
            case "4xl": 32
            case "full", "100%": 999
            default: 10
            }
        default:
            return 10
        }
    }

    /// Maps compact and large widget size tokens to native control sizes.
    static func controlSize(_ token: String?) -> ControlSize {
        switch token {
        case "3xs", "2xs", "xs", "sm":
            .small
        case "lg", "xl", "2xl", "3xl":
            .large
        default:
            .regular
        }
    }

    /// Maps widget icon size tokens to native SwiftUI fonts.
    static func iconFont(_ token: String?) -> Font {
        switch token {
        case "xs":
            .caption2
        case "sm":
            .caption
        case "lg":
            .title3
        case "xl":
            .title2
        case "2xl", "3xl":
            .title
        default:
            .body
        }
    }
}

/// Normalized chart datum used by the built-in bar chart renderer.
struct ChatKitWidgetChartPoint: Equatable, Identifiable {
    var id: String {
        label
    }

    var label: String
    var value: Double
    var colorToken: String?

    /// Extracts chart points from either a `data` or `points` array on the node.
    static func points(in node: ChatKitWidgetNode) -> [ChatKitWidgetChartPoint] {
        let values: [JSONValue] = if case let .array(data)? = node.raw["data"] {
            data
        } else if case let .array(data)? = node.raw["points"] {
            data
        } else {
            []
        }

        return values.enumerated().compactMap { index, value in
            guard case let .object(object) = value else {
                return nil
            }

            let label = object["label"]?.stringValue ?? object["name"]?.stringValue ?? "\(index + 1)"
            let numericValue = object["value"]?.numberValue ?? object["y"]?.numberValue
            guard let numericValue else {
                return nil
            }

            return ChatKitWidgetChartPoint(
                label: label,
                value: numericValue,
                colorToken: object["color"]?.stringValue,
            )
        }
    }
}

extension ChatKitWidgetNode {
    /// Returns a raw string field from the widget payload.
    func string(_ key: String) -> String? {
        raw[key]?.stringValue
    }

    /// Returns whether a raw boolean field is explicitly true.
    func bool(_ key: String) -> Bool {
        raw[key]?.boolValue == true
    }

    /// Returns a raw numeric field from the widget payload.
    func number(_ key: String) -> Double? {
        raw[key]?.numberValue
    }

    /// Returns a raw array field, or an empty array when missing or mismatched.
    func array(_ key: String) -> [JSONValue] {
        raw[key]?.arrayValue ?? []
    }

    /// Returns a raw object field from the widget payload.
    func object(_ key: String) -> [String: JSONValue]? {
        raw[key]?.objectValue
    }

    /// Resolves a raw widget color field against the current SwiftUI color scheme.
    func color(_ key: String, colorScheme: SwiftUI.ColorScheme) -> Color? {
        ChatKitWidgetColor.color(raw[key], colorScheme: colorScheme)
    }
}

extension JSONValue {
    var numberValue: Double? {
        if case let .number(value) = self {
            value
        } else {
            nil
        }
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self {
            value
        } else {
            nil
        }
    }
}

/// Resolves widget color tokens, hex strings, and light/dark color objects.
enum ChatKitWidgetColor {
    /// Resolves a JSON color value, including `{ light, dark }` objects.
    static func color(_ value: JSONValue?, colorScheme: SwiftUI.ColorScheme) -> Color? {
        switch value {
        case let .string(token):
            return color(token)
        case let .object(object):
            let themedValue = colorScheme == .dark ? object["dark"]?.stringValue : object["light"]?.stringValue
            return color(themedValue)
        default:
            return nil
        }
    }

    /// Resolves a semantic tone or CSS-style hex string into a SwiftUI color.
    static func color(_ token: String?) -> Color? {
        guard let token else {
            return nil
        }
        if let tone = ChatKitWidgetTone(rawValue: token) {
            return tone.softForeground
        }
        if let color = studioTokenColors[token] {
            return color
        }
        return Color(chatKitHex: token)
    }

    private static let studioTokenColors: [String: Color] = [
        "tertiary": .secondary.opacity(0.72),
        "text-secondary": .secondary,
        "text-tertiary": .secondary.opacity(0.72),
        "surface-secondary": .secondary.opacity(0.10),
        "surface-tertiary": .secondary.opacity(0.16),
        "gray-500": .gray,
        "slate-500": .secondary,
        "green-500": .green,
        "red-500": .red,
        "blue-500": .blue,
        "yellow-500": .yellow,
        "orange-500": .orange,
        "purple-500": .purple,
        "pink-500": .pink,
    ]
}

extension Color {
    /// Creates a color from a 6- or 8-digit widget hex string.
    init?(chatKitHex: String) {
        let value = chatKitHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
