import Foundation

/// Forward-compatible widget tree node decoded from backend JSON.
///
/// Known fields such as `type`, `id`, `key`, `children`, `value`, and common action
/// keys are exposed as typed helpers. All original fields remain in ``raw`` so host
/// apps and future renderers can inspect fields that ChatKitSwift does not yet
/// understand.
public struct ChatKitWidgetNode: Codable, Equatable, Identifiable, Sendable {
    public var type: String
    public var key: String?
    public var id: String?
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

    public var value: String? {
        raw["value"]?.stringValue
    }

    public var label: String? {
        raw["label"]?.stringValue
    }

    public var name: String? {
        raw["name"]?.stringValue
    }

    public var source: String? {
        raw["src"]?.stringValue
    }

    public var altText: String? {
        raw["alt"]?.stringValue
    }

    public var isDisabled: Bool {
        raw["disabled"]?.boolValue == true
    }

    public var children: [ChatKitWidgetNode] {
        guard case let .array(values)? = raw["children"] else {
            return []
        }

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
    }

    /// First supported action on the node, if one is present.
    ///
    /// This checks `onClickAction`, `onSubmitAction`, and `onChangeAction` in that
    /// order.
    public var action: ChatKitAction? {
        action(named: "onClickAction") ?? action(named: "onSubmitAction") ?? action(named: "onChangeAction")
    }

    /// Returns an action stored under a specific raw widget key.
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
public struct ChatKitAction: Codable, Equatable, Sendable {
    public var type: String
    public var payload: [String: JSONValue]?

    public init(type: String, payload: [String: JSONValue]? = nil) {
        self.type = type
        self.payload = payload
    }
}
