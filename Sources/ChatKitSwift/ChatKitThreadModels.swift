import Foundation

public struct ChatKitThread: Codable, Equatable, Identifiable, Sendable {
    public var title: String?
    public var id: String
    public var createdAt: Date
    public var status: ChatKitThreadStatus
    public var allowedImageDomains: [String]?
    public var metadata: [String: JSONValue]
    public var items: ChatKitPage<ChatKitThreadItem>

    public init(
        title: String? = nil,
        id: String,
        createdAt: Date,
        status: ChatKitThreadStatus = .active(.init()),
        allowedImageDomains: [String]? = nil,
        metadata: [String: JSONValue] = [:],
        items: ChatKitPage<ChatKitThreadItem> = .init()
    ) {
        self.title = title
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.allowedImageDomains = allowedImageDomains
        self.metadata = metadata
        self.items = items
    }
}

public enum ChatKitThreadStatus: Codable, Equatable, Sendable {
    case active(Active)
    case locked(Locked)
    case closed(Closed)
    case unknown(type: String, raw: [String: JSONValue])

    public struct Active: Codable, Equatable, Sendable {
        public init() {}
    }

    public struct Locked: Codable, Equatable, Sendable {
        public var reason: String?

        public init(reason: String? = nil) {
            self.reason = reason
        }
    }

    public struct Closed: Codable, Equatable, Sendable {
        public var reason: String?

        public init(reason: String? = nil) {
            self.reason = reason
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "active"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "active":
            self = .active(try ChatKitJSON.decoder.decode(Active.self, from: data))
        case "locked":
            self = .locked(try ChatKitJSON.decoder.decode(Locked.self, from: data))
        case "closed":
            self = .closed(try ChatKitJSON.decoder.decode(Closed.self, from: data))
        default:
            self = .unknown(type: type, raw: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        switch self {
        case .active:
            try container.encode("active", forKey: .init("type"))
        case let .locked(value):
            try container.encode("locked", forKey: .init("type"))
            try container.encodeIfPresent(value.reason, forKey: .init("reason"))
        case let .closed(value):
            try container.encode("closed", forKey: .init("type"))
            try container.encodeIfPresent(value.reason, forKey: .init("reason"))
        case let .unknown(type, raw):
            try container.encode(type, forKey: .init("type"))
            for (key, value) in raw where key != "type" {
                try container.encode(value, forKey: .init(key))
            }
        }
    }
}

public enum ChatKitThreadItem: Codable, Equatable, Identifiable, Sendable {
    case userMessage(ChatKitUserMessageItem)
    case assistantMessage(ChatKitAssistantMessageItem)
    case clientToolCall(ChatKitClientToolCallItem)
    case widget(ChatKitWidgetItem)
    case generatedImage(ChatKitGeneratedImageItem)
    case structuredInput(ChatKitStructuredInputItem)
    case task(ChatKitTaskItem)
    case workflow(ChatKitWorkflowItem)
    case endOfTurn(ChatKitEndOfTurnItem)
    case hiddenContext(ChatKitHiddenContextItem)
    case sdkHiddenContext(ChatKitHiddenContextItem)
    case unknown(ChatKitUnknownThreadItem)

    public var id: String {
        switch self {
        case let .userMessage(item): item.id
        case let .assistantMessage(item): item.id
        case let .clientToolCall(item): item.id
        case let .widget(item): item.id
        case let .generatedImage(item): item.id
        case let .structuredInput(item): item.id
        case let .task(item): item.id
        case let .workflow(item): item.id
        case let .endOfTurn(item): item.id
        case let .hiddenContext(item), let .sdkHiddenContext(item): item.id
        case let .unknown(item): item.id
        }
    }

    public var threadID: String {
        switch self {
        case let .userMessage(item): item.threadID
        case let .assistantMessage(item): item.threadID
        case let .clientToolCall(item): item.threadID
        case let .widget(item): item.threadID
        case let .generatedImage(item): item.threadID
        case let .structuredInput(item): item.threadID
        case let .task(item): item.threadID
        case let .workflow(item): item.threadID
        case let .endOfTurn(item): item.threadID
        case let .hiddenContext(item), let .sdkHiddenContext(item): item.threadID
        case let .unknown(item): item.threadID
        }
    }

    public var createdAt: Date {
        switch self {
        case let .userMessage(item): item.createdAt
        case let .assistantMessage(item): item.createdAt
        case let .clientToolCall(item): item.createdAt
        case let .widget(item): item.createdAt
        case let .generatedImage(item): item.createdAt
        case let .structuredInput(item): item.createdAt
        case let .task(item): item.createdAt
        case let .workflow(item): item.createdAt
        case let .endOfTurn(item): item.createdAt
        case let .hiddenContext(item), let .sdkHiddenContext(item): item.createdAt
        case let .unknown(item): item.createdAt
        }
    }

    public var assistantText: String? {
        if case let .assistantMessage(message) = self {
            message.content.map(\.text).joined()
        } else {
            nil
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "unknown"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "user_message":
            self = .userMessage(try ChatKitJSON.decoder.decode(ChatKitUserMessageItem.self, from: data))
        case "assistant_message":
            self = .assistantMessage(try ChatKitJSON.decoder.decode(ChatKitAssistantMessageItem.self, from: data))
        case "client_tool_call":
            self = .clientToolCall(try ChatKitJSON.decoder.decode(ChatKitClientToolCallItem.self, from: data))
        case "widget":
            self = .widget(try ChatKitJSON.decoder.decode(ChatKitWidgetItem.self, from: data))
        case "generated_image":
            self = .generatedImage(try ChatKitJSON.decoder.decode(ChatKitGeneratedImageItem.self, from: data))
        case "structured_input":
            self = .structuredInput(try ChatKitJSON.decoder.decode(ChatKitStructuredInputItem.self, from: data))
        case "task":
            self = .task(try ChatKitJSON.decoder.decode(ChatKitTaskItem.self, from: data))
        case "workflow":
            self = .workflow(try ChatKitJSON.decoder.decode(ChatKitWorkflowItem.self, from: data))
        case "end_of_turn":
            self = .endOfTurn(try ChatKitJSON.decoder.decode(ChatKitEndOfTurnItem.self, from: data))
        case "hidden_context_item":
            self = .hiddenContext(try ChatKitJSON.decoder.decode(ChatKitHiddenContextItem.self, from: data))
        case "sdk_hidden_context":
            self = .sdkHiddenContext(try ChatKitJSON.decoder.decode(ChatKitHiddenContextItem.self, from: data))
        default:
            self = .unknown(try ChatKitJSON.decoder.decode(ChatKitUnknownThreadItem.self, from: data))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .userMessage(item):
            try item.encode(to: encoder)
        case let .assistantMessage(item):
            try item.encode(to: encoder)
        case let .clientToolCall(item):
            try item.encode(to: encoder)
        case let .widget(item):
            try item.encode(to: encoder)
        case let .generatedImage(item):
            try item.encode(to: encoder)
        case let .structuredInput(item):
            try item.encode(to: encoder)
        case let .task(item):
            try item.encode(to: encoder)
        case let .workflow(item):
            try item.encode(to: encoder)
        case let .endOfTurn(item):
            try item.encode(to: encoder)
        case let .hiddenContext(item), let .sdkHiddenContext(item):
            try item.encode(to: encoder)
        case let .unknown(item):
            try item.encode(to: encoder)
        }
    }

    public func applying(_ update: ChatKitThreadItemUpdate) -> ChatKitThreadItem {
        switch (self, update) {
        case let (.assistantMessage(message), .assistantMessageContentPartAdded(update)):
            .assistantMessage(message.settingContent(update.content, at: update.contentIndex))
        case let (.assistantMessage(message), .assistantMessageContentPartTextDelta(update)):
            .assistantMessage(message.appendingText(update.delta, at: update.contentIndex))
        case let (.assistantMessage(message), .assistantMessageContentPartAnnotationAdded(update)):
            .assistantMessage(message.appendingAnnotation(update.annotation, contentIndex: update.contentIndex, annotationIndex: update.annotationIndex))
        case let (.assistantMessage(message), .assistantMessageContentPartDone(update)):
            .assistantMessage(message.settingContent(update.content, at: update.contentIndex))
        case let (.widget(widget), .widgetRootUpdated(update)):
            .widget(widget.replacingWidget(update.widget))
        case let (.widget(widget), .widgetStreamingTextValueDelta(update)):
            .widget(widget.appendingWidgetText(update.delta, componentID: update.componentID))
        case let (.widget(widget), .widgetComponentUpdated(update)):
            .widget(widget.replacingComponent(update.component, componentID: update.componentID))
        default:
            self
        }
    }
}

public struct ChatKitUserMessageItem: Codable, Equatable, Sendable {
    public var type = "user_message"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var content: [ChatKitUserMessageContent]
    public var attachments: [ChatKitAttachment]
    public var quotedText: String?
    public var inferenceOptions: ChatKitInferenceOptions

    public init(id: String, threadID: String, createdAt: Date, content: [ChatKitUserMessageContent], attachments: [ChatKitAttachment] = [], quotedText: String? = nil, inferenceOptions: ChatKitInferenceOptions = .init()) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.content = content
        self.attachments = attachments
        self.quotedText = quotedText
        self.inferenceOptions = inferenceOptions
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case content
        case attachments
        case quotedText
        case inferenceOptions
    }
}

public struct ChatKitAssistantMessageItem: Codable, Equatable, Sendable {
    public var type = "assistant_message"
    public var id: String
    public var threadID: String
    public var createdAt: Date
    public var content: [ChatKitAssistantMessageContent]

    public init(id: String, threadID: String, createdAt: Date, content: [ChatKitAssistantMessageContent]) {
        self.id = id
        self.threadID = threadID
        self.createdAt = createdAt
        self.content = content
    }

    public func appendingText(_ text: String, at index: Int = 0) -> ChatKitAssistantMessageItem {
        var copy = self
        while copy.content.count <= index {
            copy.content.append(.init(text: "", annotations: []))
        }
        copy.content[index].text += text
        return copy
    }

    public func settingContent(_ content: ChatKitAssistantMessageContent, at index: Int) -> ChatKitAssistantMessageItem {
        var copy = self
        while copy.content.count <= index {
            copy.content.append(.init(text: "", annotations: []))
        }
        copy.content[index] = content
        return copy
    }

    public func appendingAnnotation(_ annotation: ChatKitAnnotation, contentIndex: Int, annotationIndex: Int) -> ChatKitAssistantMessageItem {
        var copy = self
        while copy.content.count <= contentIndex {
            copy.content.append(.init(text: "", annotations: []))
        }
        if annotationIndex <= copy.content[contentIndex].annotations.count {
            copy.content[contentIndex].annotations.insert(annotation, at: annotationIndex)
        } else {
            copy.content[contentIndex].annotations.append(annotation)
        }
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case threadID = "threadId"
        case createdAt
        case content
    }
}
