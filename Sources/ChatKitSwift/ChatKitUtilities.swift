import Foundation

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension [String: JSONValue] {
    var foundationObject: [String: Any] {
        mapValues(\.foundationObject)
    }
}

extension JSONValue {
    var foundationObject: Any {
        switch self {
        case let .string(value):
            value
        case let .number(value):
            value
        case let .bool(value):
            value
        case let .object(value):
            value.foundationObject
        case let .array(value):
            value.map(\.foundationObject)
        case .null:
            NSNull()
        }
    }
}

extension ChatKitWidgetNode {
    func appendingText(_ text: String, componentID: String) -> ChatKitWidgetNode {
        guard id != componentID else {
            var copy = self
            let current = copy.raw["value"]?.stringValue ?? ""
            copy.raw["value"] = .string(current + text)
            return copy
        }

        var copy = self
        guard case let .array(children)? = raw["children"] else {
            return copy
        }

        copy.raw["children"] = .array(children.map { child in
            guard case let .object(object) = child else {
                return child
            }
            let node = ChatKitWidgetNode(
                type: object["type"]?.stringValue ?? "Unknown",
                key: object["key"]?.stringValue,
                id: object["id"]?.stringValue,
                raw: object,
            )
            return .object(node.appendingText(text, componentID: componentID).raw)
        })
        return copy
    }

    func replacingComponent(_ component: ChatKitWidgetNode, componentID: String) -> ChatKitWidgetNode {
        if id == componentID {
            return component
        }

        var copy = self
        guard case let .array(children)? = raw["children"] else {
            return copy
        }

        copy.raw["children"] = .array(children.map { child in
            guard case let .object(object) = child else {
                return child
            }

            let node = ChatKitWidgetNode(
                type: object["type"]?.stringValue ?? "Unknown",
                key: object["key"]?.stringValue,
                id: object["id"]?.stringValue,
                raw: object,
            )
            return .object(node.replacingComponent(component, componentID: componentID).raw)
        })
        return copy
    }
}
