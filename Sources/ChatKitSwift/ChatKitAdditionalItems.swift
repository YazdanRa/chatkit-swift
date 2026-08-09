import Foundation

public struct ChatKitClientToolCallItem: Codable, Equatable, Sendable {
    public var type = "client_tool_call"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var status: String
    public var callID: String
    public var name: String
    public var arguments: [String: JSONValue]
    public var output: JSONValue?

    public init(id: String, threadID: String, createdAt: Date, status: String = "pending", callID: String, name: String, arguments: [String: JSONValue], output: JSONValue? = nil) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.status = status
        self.callID = callID
        self.name = name
        self.arguments = arguments
        self.output = output
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case status
        case callID = "callId"
        case name
        case arguments
        case output
    }
}

public struct ChatKitWidgetItem: Codable, Equatable, Sendable {
    public var type = "widget"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var widget: ChatKitWidgetNode
    public var copyText: String?

    public init(id: String, threadID: String, createdAt: Date, widget: ChatKitWidgetNode, copyText: String? = nil) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.widget = widget
        self.copyText = copyText
    }

    public func replacingWidget(_ widget: ChatKitWidgetNode) -> ChatKitWidgetItem {
        var copy = self
        copy.widget = widget
        return copy
    }

    public func appendingWidgetText(_ text: String, componentID: String, done: Bool) -> ChatKitWidgetItem {
        var copy = self
        copy.widget = copy.widget.appendingText(text, componentID: componentID, done: done)
        return copy
    }

    public func replacingComponent(_ component: ChatKitWidgetNode, componentID: String) -> ChatKitWidgetItem {
        var copy = self
        copy.widget = copy.widget.replacingComponent(component, componentID: componentID)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case widget
        case copyText
    }
}

public struct ChatKitImageGenerationItem: Codable, Equatable, Sendable {
    public var type = "image_generation"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var image: ChatKitGeneratedImageItem.GeneratedImage?
    public var progress: Double?

    public init(
        id: String,
        threadID: String,
        createdAt: Date,
        image: ChatKitGeneratedImageItem.GeneratedImage? = nil,
        progress: Double? = nil,
    ) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.image = image
        self.progress = progress
    }

    public func updatingPreview(image: ChatKitGeneratedImageItem.GeneratedImage, progress: Double?) -> ChatKitImageGenerationItem {
        var copy = self
        copy.image = image
        copy.progress = progress
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case image
        case progress
    }
}

public struct ChatKitGeneratedImageItem: Codable, Equatable, Sendable {
    public var type = "generated_image"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var image: GeneratedImage?

    public struct GeneratedImage: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var url: URL
        public var progress: Double?

        public init(id: String, url: URL, progress: Double? = nil) {
            self.id = id
            self.url = url
            self.progress = progress
        }
    }

    public init(id: String, threadID: String, createdAt: Date, image: GeneratedImage? = nil) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.image = image
    }

    public func updatingImage(_ image: GeneratedImage, progress: Double?) -> ChatKitGeneratedImageItem {
        var copy = self
        copy.image = .init(id: image.id, url: image.url, progress: progress ?? image.progress)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case image
    }
}

public struct ChatKitStructuredInputItem: Codable, Equatable, Sendable {
    public var type = "structured_input"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var status: String
    public var inputs: [StructuredInput]

    public struct StructuredInput: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var type: String
        public var question: String
        public var description: String?
        public var options: [Option]?
        public var multiple: Bool?
        public var answer: ChatKitStructuredInputSubmission.Answer?

        public struct Option: Codable, Equatable, Sendable {
            public var value: String
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case status
        case inputs
    }
}

/// Answers submitted for a structured input item.
///
/// Use this with ``ChatKitSession/submitStructuredInput(_:itemID:)``. `status`
/// defaults to `"answered"`; backends may also use other statuses for skipped or
/// deferred submissions. Each entry in ``answers`` is keyed by the structured input
/// field ID.
public struct ChatKitStructuredInputSubmission: Codable, Equatable, Sendable {
    public var status: String
    public var answers: [String: Answer]

    public init(status: String = "answered", answers: [String: Answer] = [:]) {
        self.status = status
        self.answers = answers
    }

    public struct Answer: Codable, Equatable, Sendable {
        public var values: [String]
        public var skipped: Bool

        public init(values: [String] = [], skipped: Bool = false) {
            self.values = values
            self.skipped = skipped
        }
    }
}

public struct ChatKitTaskItem: Codable, Equatable, Sendable {
    public var type = "task"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var task: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case task
    }
}

public struct ChatKitWorkflowItem: Codable, Equatable, Sendable {
    public var type = "workflow"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var workflow: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case workflow
    }
}

public struct ChatKitEndOfTurnItem: Codable, Equatable, Sendable {
    public var type = "end_of_turn"
    public var id: String
    public var threadID: String
    public var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
    }
}

public struct ChatKitHiddenContextItem: Codable, Equatable, Sendable {
    public var type: String
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var content: String

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case content
    }
}

public struct ChatKitUnknownThreadItem: Codable, Equatable, Sendable {
    public var type: String
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var raw: [String: JSONValue]

    public init(from decoder: Decoder) throws {
        raw = try [String: JSONValue](from: decoder).chatKitProtocolKeyedObject
        type = raw["type"]?.stringValue ?? "unknown"
        id = raw["id"]?.stringValue ?? UUID().uuidString
        threadID = raw["thread_id"]?.stringValue ?? ""
        if let createdAtString = raw["created_at"]?.stringValue,
           let data = "\"\(createdAtString)\"".data(using: .utf8),
           let date = try? ChatKitJSON.decoder.decode(Date.self, from: data)
        {
            createdAt = date
        } else {
            createdAt = .now
        }
    }

    public func encode(to encoder: Encoder) throws {
        try raw.encode(to: encoder)
    }
}
