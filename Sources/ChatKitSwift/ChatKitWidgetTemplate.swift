import Foundation

/// Renders a Widget Studio JSON template into a native widget node.
///
/// Widget Studio's `convert-widget-to-file` endpoint returns JSON with
/// `{{ (name) | tojson }}` placeholders. `ChatKitWidgetTemplate` replaces those
/// placeholders with values from `state`, then decodes the result as a
/// ``ChatKitWidgetNode``.
public struct ChatKitWidgetTemplate: Equatable, Sendable {
    public var template: String
    public var state: [String: JSONValue]

    public init(template: String, state: [String: JSONValue]) {
        self.template = template
        self.state = state
    }

    /// Renders the template and decodes it as a widget node.
    public func renderNode() throws -> ChatKitWidgetNode {
        let renderedJSON = try renderJSON()
        guard let data = renderedJSON.data(using: .utf8) else {
            throw ChatKitWidgetTemplateError.invalidRenderedJSON(renderedJSON)
        }

        do {
            return try ChatKitJSON.decoder.decode(ChatKitWidgetNode.self, from: data)
        } catch {
            throw ChatKitWidgetTemplateError.invalidRenderedJSON(renderedJSON)
        }
    }

    /// Renders the template into raw JSON text.
    public func renderJSON() throws -> String {
        let expression = try NSRegularExpression(pattern: #"\{\{\s*\(([A-Za-z_][A-Za-z0-9_]*)\)\s*\|\s*tojson\s*\}\}"#)
        let range = NSRange(template.startIndex ..< template.endIndex, in: template)
        let matches = expression.matches(in: template, range: range)
        var rendered = template

        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let placeholderRange = Range(match.range(at: 1), in: template),
                  let replacementRange = Range(match.range(at: 0), in: rendered)
            else {
                continue
            }

            let key = String(template[placeholderRange])
            guard let value = state[key] else {
                throw ChatKitWidgetTemplateError.missingStateValue(key)
            }

            rendered.replaceSubrange(replacementRange, with: try Self.jsonString(for: value))
        }

        return rendered
    }

    private static func jsonString(for value: JSONValue) throws -> String {
        let data = try ChatKitJSON.encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "null"
    }
}

public enum ChatKitWidgetTemplateError: Error, Equatable, LocalizedError, Sendable {
    case missingStateValue(String)
    case invalidRenderedJSON(String)

    public var errorDescription: String? {
        switch self {
        case let .missingStateValue(key):
            "Widget template references missing state value '\(key)'."
        case .invalidRenderedJSON:
            "Widget template rendered invalid JSON."
        }
    }
}
