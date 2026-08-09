import Foundation

/// Forward-compatible widget tree node decoded from backend JSON.
///
/// Known fields such as `type`, `id`, `key`, `children`, `value`, and common action
/// keys are exposed as typed helpers. All original fields remain in ``raw`` so host
/// apps and future renderers can inspect fields that ChatKitSwift does not yet
/// understand.
///
/// The built-in renderer switches on ``type`` for supported primitives such as
/// layout containers, text, controls, tables, and charts. Unknown node types are
/// still rendered as labeled containers with any decoded ``children``.
public struct ChatKitWidgetNode: Codable, Equatable, Identifiable, Sendable {
    /// Backend component type used by the built-in renderer.
    public var type: String
    /// Optional backend key used as a stable SwiftUI identity fallback.
    public var key: String?
    /// Optional backend identifier used as the preferred SwiftUI identity.
    public var id: String?
    /// Original widget fields, including values not modeled by ChatKitSwift yet.
    public var raw: [String: JSONValue]

    public init(type: String, key: String? = nil, id: String? = nil, raw: [String: JSONValue] = [:]) {
        self.type = type
        self.key = key
        self.id = id
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        self.raw = raw
        type = raw["type"]?.stringValue ?? "Unknown"
        key = raw["key"]?.stringValue
        id = raw["id"]?.stringValue
    }

    public func encode(to encoder: Encoder) throws {
        var encoded = raw
        encoded["type"] = .string(type)
        if let key {
            encoded["key"] = .string(key)
        }
        if let id {
            encoded["id"] = .string(id)
        }
        try encoded.encode(to: encoder)
    }

    /// Stable identity for SwiftUI rendering.
    ///
    /// Prefers `id`, then `key`, then a fallback derived from the node type and raw
    /// payload.
    public var stableID: String {
        id ?? key ?? "\(type)-\(raw.description)"
    }

    /// Text value used by text-like, icon, badge, label, and option nodes.
    public var value: String? {
        raw["value"]?.stringValue
    }

    /// User-facing label used by controls and badges.
    public var label: String? {
        raw["label"]?.stringValue
    }

    /// Form field name or icon name, depending on the widget node type.
    public var name: String? {
        raw["name"]?.stringValue
    }

    /// Remote image source used by `Image` nodes.
    public var source: String? {
        raw["src"]?.stringValue
    }

    /// Accessibility label used by `Image` nodes.
    public var altText: String? {
        raw["alt"]?.stringValue
    }

    /// Whether the widget control should be rendered disabled.
    public var isDisabled: Bool {
        raw["disabled"]?.boolValue == true
    }

    /// Child widget nodes decoded from the raw `children` array.
    ///
    /// Non-object child values are ignored so partially forward-compatible payloads
    /// can still render their supported descendants.
    public var children: [ChatKitWidgetNode] {
        switch raw["children"] {
        case let .array(values):
            return values.compactMap { value in
                guard case let .object(object) = value else {
                    return nil
                }
                return ChatKitWidgetNode(
                    type: object["type"]?.stringValue ?? "Unknown",
                    key: object["key"]?.stringValue,
                    id: object["id"]?.stringValue,
                    raw: object,
                )
            }
        case let .object(object):
            return [
                ChatKitWidgetNode(
                    type: object["type"]?.stringValue ?? "Unknown",
                    key: object["key"]?.stringValue,
                    id: object["id"]?.stringValue,
                    raw: object,
                ),
            ]
        default:
            return []
        }
    }

    /// First supported action on the node, if one is present.
    ///
    /// This checks `onClickAction`, `onSubmitAction`, and `onChangeAction` in that
    /// order. Buttons and clickable list items use click actions, forms use submit
    /// actions, and input controls use change actions with the current value added
    /// to the action payload.
    public var action: ChatKitAction? {
        action(named: "onClickAction") ?? action(named: "onSubmitAction") ?? action(named: "onChangeAction")
    }

    /// Returns an action stored under a specific raw widget key.
    ///
    /// The action keeps the backend `type` and optional `payload` object so host
    /// apps can handle it locally or let ``ChatKitSession`` forward it.
    public func action(named key: String) -> ChatKitAction? {
        guard case let .object(object)? = raw[key],
              let type = object["type"]?.stringValue
        else {
            return nil
        }

        return ChatKitAction(type: type, payload: object["payload"]?.objectValue)
    }
}

/// Action payload emitted by a widget node.
///
/// Widget actions preserve the backend action `type` and optional JSON payload.
/// When input controls emit change actions, ChatKitSwift adds the field `name` and
/// current `value` before delivery.
public struct ChatKitAction: Codable, Equatable, Sendable {
    /// Backend action identifier.
    public var type: String
    /// Optional backend-defined JSON payload.
    public var payload: [String: JSONValue]?

    public init(type: String, payload: [String: JSONValue]? = nil) {
        self.type = type
        self.payload = payload
    }
}
