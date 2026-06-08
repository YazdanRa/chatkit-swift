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
        color(hex: foregroundHex)
    }

    /// Background color for solid controls and badges.
    var solidBackground: Color {
        color(hex: solidHex)
    }

    /// Low-emphasis background color for outline and soft widget treatments.
    var softBackground: Color {
        color(hex: softHex)
    }

    /// Low-emphasis foreground color for outline and soft widget treatments.
    var softForeground: Color {
        color(hex: accentHex)
    }

    var foregroundHex: String {
        switch self {
        case .primary, .secondary, .info, .discovery, .success, .warning, .danger:
            "#FFFFFF"
        }
    }

    var solidHex: String {
        switch self {
        case .primary:
            "#181818"
        case .secondary:
            "#5D5D5D"
        case .info:
            "#0285FF"
        case .discovery:
            "#924FF7"
        case .success:
            "#00A240"
        case .warning:
            "#E25507"
        case .danger:
            "#E02E2A"
        }
    }

    var softHex: String {
        switch self {
        case .primary:
            "#F3F3F3"
        case .secondary:
            "#EDEDED"
        case .info:
            "#E5F3FF"
        case .discovery:
            "#EFE5FE"
        case .success:
            "#D9F4E4"
        case .warning:
            "#FFE7D9"
        case .danger:
            "#FFD9D9"
        }
    }

    var accentHex: String {
        switch self {
        case .primary:
            "#0D0D0D"
        case .secondary:
            "#282828"
        case .info:
            "#0169CC"
        case .discovery:
            "#8046D9"
        case .success:
            "#008635"
        case .warning:
            "#B9480D"
        case .danger:
            "#E02E2A"
        }
    }

    private func color(hex: String) -> Color {
        Color(chatKitHex: hex) ?? .primary
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

    static func titlePointSize(_ token: String?) -> CGFloat {
        switch token {
        case "sm":
            18
        case "lg":
            24
        case "xl":
            32
        case "2xl":
            36
        case "3xl":
            48
        case "4xl":
            60
        case "5xl":
            72
        default:
            20
        }
    }

    static func titleLineHeight(_ token: String?) -> CGFloat {
        switch token {
        case "sm":
            26
        case "lg":
            28
        case "xl":
            38
        case "2xl":
            42
        case "3xl":
            48
        case "4xl":
            60
        case "5xl":
            72
        default:
            26
        }
    }

    static func textPointSize(_ token: String?) -> CGFloat {
        switch token {
        case "xs":
            12
        case "sm":
            14
        case "lg":
            18
        case "xl":
            20
        default:
            16
        }
    }

    static func textLineHeight(_ token: String?) -> CGFloat {
        switch token {
        case "xs":
            18
        case "sm":
            20
        case "lg":
            29
        case "xl":
            26
        default:
            24
        }
    }

    static func captionPointSize(_ token: String?) -> CGFloat {
        switch token {
        case "md":
            14
        case "lg":
            16
        default:
            12
        }
    }

    static func captionLineHeight(_ token: String?) -> CGFloat {
        switch token {
        case "md":
            20
        case "lg":
            24
        default:
            15.6
        }
    }

    static func additionalLineSpacing(pointSize: CGFloat, lineHeight: CGFloat) -> CGFloat {
        max(0, lineHeight - pointSize - 4)
    }

    static func stackGap(_ value: JSONValue?, containerType: String, childTypes: [String]) -> CGFloat? {
        let gap = spacing(value)
        guard let gap else {
            return nil
        }
        if case .string? = value {
            if containerType == "Col", childTypes.allSatisfy({ $0 == "Button" }) {
                return 0
            }
            if containerType == "Row", childTypes.allSatisfy({ $0 == "Box" }) {
                return 0
            }
        }
        return gap
    }

    static func buttonHeight(_ token: String?) -> CGFloat {
        switch token {
        case "3xs":
            22
        case "2xs":
            24
        case "xs":
            26
        case "sm":
            28
        case "md":
            32
        case "xl":
            40
        case "2xl":
            44
        case "3xl":
            48
        default:
            36
        }
    }

    static func buttonFontPointSize(_ token: String?) -> CGFloat {
        switch token {
        case "2xl", "3xl":
            16
        case "3xs", "2xs":
            12
        default:
            14
        }
    }

    static func buttonHorizontalPadding(_ token: String?, pill: Bool) -> CGFloat {
        let base = switch token {
        case "3xs":
            CGFloat(6)
        case "2xs", "xs":
            CGFloat(8)
        case "sm":
            CGFloat(10)
        case "xl", "2xl":
            CGFloat(14)
        case "3xl":
            CGFloat(16)
        default:
            CGFloat(12)
        }
        return pill ? base * 1.33 : base
    }

    static func buttonCornerRadius(_ value: JSONValue?, pill: Bool) -> CGFloat {
        if value != nil {
            return radius(value)
        }
        return 999
    }

    /// Maps widget icon size tokens to native SwiftUI fonts.
    static func iconFont(_ token: String?) -> Font {
        switch token {
        case "xs":
            .system(size: 12)
        case "sm":
            .system(size: 14)
        case "lg":
            .system(size: 20)
        case "xl":
            .system(size: 22)
        case "2xl":
            .system(size: 24)
        case "3xl":
            .system(size: 26)
        default:
            .system(size: 18)
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
