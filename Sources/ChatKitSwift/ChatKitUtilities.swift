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

    var chatKitProtocolKeyedObject: [String: JSONValue] {
        Dictionary(uniqueKeysWithValues: map { key, value in
            (key.chatKitProtocolKey, value.chatKitProtocolKeyedValue)
        })
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

    var chatKitProtocolKeyedValue: JSONValue {
        switch self {
        case let .object(value):
            .object(value.chatKitProtocolKeyedObject)
        case let .array(value):
            .array(value.map(\.chatKitProtocolKeyedValue))
        case .string, .number, .bool, .null:
            self
        }
    }
}

private extension String {
    var chatKitProtocolKey: String {
        guard contains(where: \.isUppercase) else {
            return self
        }

        var result = ""
        for character in self {
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("_")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
        return result
    }
}

extension ChatKitWidgetNode {
    func appendingText(_ text: String, componentID: String, done: Bool) -> ChatKitWidgetNode {
        guard id != componentID else {
            guard type == "Markdown" || type == "Text" else {
                return self
            }
            var copy = self
            let current = copy.raw["value"]?.stringValue ?? ""
            copy.raw["value"] = .string(current + text)
            copy.raw["done"] = .bool(done)
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
            return .object(node.appendingText(text, componentID: componentID, done: done).raw)
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
