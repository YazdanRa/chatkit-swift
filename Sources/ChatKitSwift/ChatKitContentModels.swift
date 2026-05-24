import Foundation

/// User-authored input sent to a ChatKit thread.
public struct ChatKitUserMessageInput: Codable, Equatable, Sendable {
    public var content: [ChatKitUserMessageContent]
    public var attachments: [String]
    public var quotedText: String?
    public var inferenceOptions: ChatKitInferenceOptions

    public init(content: [ChatKitUserMessageContent], attachments: [String] = [], quotedText: String? = nil, inferenceOptions: ChatKitInferenceOptions = .init()) {
        self.content = content
        self.attachments = attachments
        self.quotedText = quotedText
        self.inferenceOptions = inferenceOptions
    }
}

/// A content part in a user message.
///
/// `inputText` carries plain text. `inputTag` carries an entity mention or rich tag
/// selected through the composer. Unknown content parts are preserved as raw JSON so
/// clients remain compatible with newer protocol fields.
public enum ChatKitUserMessageContent: Codable, Equatable, Sendable {
    case inputText(ChatKitInputTextContent)
    case inputTag(ChatKitInputTagContent)
    case unknown(type: String, raw: [String: JSONValue])

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "unknown"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "input_text":
            self = .inputText(try ChatKitJSON.decoder.decode(ChatKitInputTextContent.self, from: data))
        case "input_tag":
            self = .inputTag(try ChatKitJSON.decoder.decode(ChatKitInputTagContent.self, from: data))
        default:
            self = .unknown(type: type, raw: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .inputText(value):
            try value.encode(to: encoder)
        case let .inputTag(value):
            try value.encode(to: encoder)
        case let .unknown(type, raw):
            var encoded = raw
            encoded["type"] = .string(type)
            try encoded.encode(to: encoder)
        }
    }

    /// Text suitable for rendering in the local transcript.
    public var displayText: String {
        switch self {
        case let .inputText(value):
            value.text
        case let .inputTag(value):
            value.text
        case let .unknown(type, _):
            type
        }
    }
}

public struct ChatKitInputTextContent: Codable, Equatable, Sendable {
    public var type = "input_text"
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

public struct ChatKitInputTagContent: Codable, Equatable, Sendable {
    public var type = "input_tag"
    public var text: String
    public var id: String
    public var group: String?
    public var data: [String: JSONValue]
    public var interactive: Bool?

    public init(text: String, id: String, group: String? = nil, data: [String: JSONValue] = [:], interactive: Bool? = nil) {
        self.text = text
        self.id = id
        self.group = group
        self.data = data
        self.interactive = interactive
    }
}

public struct ChatKitInferenceOptions: Codable, Equatable, Sendable {
    public var toolChoice: ChatKitToolChoice?
    public var model: String?

    public init(toolChoice: ChatKitToolChoice? = nil, model: String? = nil) {
        self.toolChoice = toolChoice
        self.model = model
    }
}

public struct ChatKitToolChoice: Codable, Equatable, Sendable {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}

public enum ChatKitAttachment: Codable, Equatable, Identifiable, Sendable {
    case file(File)
    case image(Image)
    case unknown(id: String, type: String, raw: [String: JSONValue])

    public var id: String {
        switch self {
        case let .file(file):
            file.id
        case let .image(image):
            image.id
        case let .unknown(id, _, _):
            id
        }
    }

    public struct File: Codable, Equatable, Sendable {
        public var type = "file"
        public var id: String
        public var name: String
        public var mimeType: String

        public init(id: String, name: String, mimeType: String) {
            self.id = id
            self.name = name
            self.mimeType = mimeType
        }
    }

    public struct Image: Codable, Equatable, Sendable {
        public var type = "image"
        public var id: String
        public var previewURL: URL
        public var name: String
        public var mimeType: String

        public init(id: String, previewURL: URL, name: String, mimeType: String) {
            self.id = id
            self.previewURL = previewURL
            self.name = name
            self.mimeType = mimeType
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case id
            case previewURL = "previewUrl"
            case name
            case mimeType = "mimeType"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "unknown"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "file":
            self = .file(try ChatKitJSON.decoder.decode(File.self, from: data))
        case "image":
            self = .image(try ChatKitJSON.decoder.decode(Image.self, from: data))
        default:
            self = .unknown(id: raw["id"]?.stringValue ?? UUID().uuidString, type: type, raw: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .file(value):
            try value.encode(to: encoder)
        case let .image(value):
            try value.encode(to: encoder)
        case let .unknown(_, type, raw):
            var encoded = raw
            encoded["type"] = .string(type)
            try encoded.encode(to: encoder)
        }
    }
}

public struct ChatKitAssistantMessageContent: Codable, Equatable, Sendable {
    public var type = "output_text"
    public var text: String
    public var annotations: [ChatKitAnnotation]

    public init(text: String, annotations: [ChatKitAnnotation] = []) {
        self.text = text
        self.annotations = annotations
    }
}

public struct ChatKitAnnotation: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var type: String
    public var title: String?
    public var url: URL?
    public var metadata: [String: JSONValue]

    public init(id: String = UUID().uuidString, type: String = "annotation", title: String? = nil, url: URL? = nil, metadata: [String: JSONValue] = [:]) {
        self.id = id
        self.type = type
        self.title = title
        self.url = url
        self.metadata = metadata
    }
}

public struct ChatKitEntity: Codable, Equatable, Identifiable, Sendable {
    public var title: String
    public var id: String
    public var icon: String?
    public var interactive: Bool?
    public var group: String?
    public var data: [String: String]

    public init(title: String, id: String, icon: String? = nil, interactive: Bool? = nil, group: String? = nil, data: [String: String] = [:]) {
        self.title = title
        self.id = id
        self.icon = icon
        self.interactive = interactive
        self.group = group
        self.data = data
    }
}

public struct ChatKitLocalFile: Equatable, Identifiable, Sendable {
    public var id: String
    public var url: URL
    public var name: String
    public var mimeType: String

    public init(id: String = UUID().uuidString, url: URL, name: String, mimeType: String) {
        self.id = id
        self.url = url
        self.name = name
        self.mimeType = mimeType
    }
}
