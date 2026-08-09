import Foundation

/// Streaming event emitted by a ChatKit-compatible backend.
///
/// Events mutate ``ChatKitConversationState`` in arrival order. Known event types
/// decode into strongly typed cases, while unknown event payloads are preserved in
/// ``unknown(type:raw:)`` so newer backend events do not break older clients.
public enum ChatKitEvent: Codable, Equatable, Sendable {
    case threadCreated(ThreadCreated)
    case threadUpdated(ThreadUpdated)
    case threadItemAdded(ThreadItemAdded)
    case threadItemUpdated(ThreadItemUpdated)
    case threadItemDone(ThreadItemDone)
    case threadItemRemoved(ThreadItemRemoved)
    case threadItemReplaced(ThreadItemReplaced)
    case streamOptions(StreamOptionsEvent)
    case progressUpdate(ProgressUpdate)
    case clientEffect(ClientEffect)
    case error(ErrorEvent)
    case notice(Notice)
    case unknown(type: String, raw: [String: JSONValue])

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "unknown"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "thread.created":
            self = try .threadCreated(ChatKitJSON.decoder.decode(ThreadCreated.self, from: data))
        case "thread.updated":
            self = try .threadUpdated(ChatKitJSON.decoder.decode(ThreadUpdated.self, from: data))
        case "thread.item.added":
            self = try .threadItemAdded(ChatKitJSON.decoder.decode(ThreadItemAdded.self, from: data))
        case "thread.item.updated":
            self = try .threadItemUpdated(ChatKitJSON.decoder.decode(ThreadItemUpdated.self, from: data))
        case "thread.item.done":
            self = try .threadItemDone(ChatKitJSON.decoder.decode(ThreadItemDone.self, from: data))
        case "thread.item.removed":
            self = try .threadItemRemoved(ChatKitJSON.decoder.decode(ThreadItemRemoved.self, from: data))
        case "thread.item.replaced":
            self = try .threadItemReplaced(ChatKitJSON.decoder.decode(ThreadItemReplaced.self, from: data))
        case "stream_options":
            self = try .streamOptions(ChatKitJSON.decoder.decode(StreamOptionsEvent.self, from: data))
        case "progress_update":
            self = try .progressUpdate(ChatKitJSON.decoder.decode(ProgressUpdate.self, from: data))
        case "client_effect":
            self = try .clientEffect(ChatKitJSON.decoder.decode(ClientEffect.self, from: data))
        case "error":
            self = try .error(ChatKitJSON.decoder.decode(ErrorEvent.self, from: data))
        case "notice":
            self = try .notice(ChatKitJSON.decoder.decode(Notice.self, from: data))
        default:
            self = .unknown(type: type, raw: raw.chatKitProtocolKeyedObject)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .threadCreated(value):
            try value.encode(to: encoder)
        case let .threadUpdated(value):
            try value.encode(to: encoder)
        case let .threadItemAdded(value):
            try value.encode(to: encoder)
        case let .threadItemUpdated(value):
            try value.encode(to: encoder)
        case let .threadItemDone(value):
            try value.encode(to: encoder)
        case let .threadItemRemoved(value):
            try value.encode(to: encoder)
        case let .threadItemReplaced(value):
            try value.encode(to: encoder)
        case let .streamOptions(value):
            try value.encode(to: encoder)
        case let .progressUpdate(value):
            try value.encode(to: encoder)
        case let .clientEffect(value):
            try value.encode(to: encoder)
        case let .error(value):
            try value.encode(to: encoder)
        case let .notice(value):
            try value.encode(to: encoder)
        case let .unknown(type, raw):
            var encoded = raw
            encoded["type"] = .string(type)
            try encoded.encode(to: encoder)
        }
    }

    public struct ThreadCreated: Codable, Equatable, Sendable {
        public var type = "thread.created"
        public var thread: ChatKitThread

        public init(thread: ChatKitThread) {
            self.thread = thread
        }
    }

    public struct ThreadUpdated: Codable, Equatable, Sendable {
        public var type = "thread.updated"
        public var thread: ChatKitThread
    }

    public struct ThreadItemAdded: Codable, Equatable, Sendable {
        public var type = "thread.item.added"
        public var item: ChatKitThreadItem

        public init(item: ChatKitThreadItem) {
            self.item = item
        }
    }

    public struct ThreadItemUpdated: Codable, Equatable, Sendable {
        public var type = "thread.item.updated"
        public var itemID: String
        public var update: ChatKitThreadItemUpdate

        public init(itemID: String, update: ChatKitThreadItemUpdate) {
            self.itemID = itemID
            self.update = update
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case itemID = "itemId"
            case update
        }
    }

    public struct ThreadItemDone: Codable, Equatable, Sendable {
        public var type = "thread.item.done"
        public var item: ChatKitThreadItem

        public init(item: ChatKitThreadItem) {
            self.item = item
        }
    }

    public struct ThreadItemRemoved: Codable, Equatable, Sendable {
        public var type = "thread.item.removed"
        public var itemID: String

        private enum CodingKeys: String, CodingKey {
            case type
            case itemID = "itemId"
        }
    }

    public struct ThreadItemReplaced: Codable, Equatable, Sendable {
        public var type = "thread.item.replaced"
        public var item: ChatKitThreadItem
    }

    public struct StreamOptionsEvent: Codable, Equatable, Sendable {
        public var type = "stream_options"
        public var streamOptions: StreamOptions
    }

    public struct StreamOptions: Codable, Equatable, Sendable {
        public var allowCancel: Bool
    }

    public struct ProgressUpdate: Codable, Equatable, Sendable {
        public var type = "progress_update"
        public var icon: String?
        public var text: String

        public init(icon: String? = nil, text: String) {
            self.icon = icon
            self.text = text
        }
    }

    public struct ClientEffect: Codable, Equatable, Sendable {
        public var type = "client_effect"
        public var name: String
        public var data: [String: JSONValue]
    }

    public struct ErrorEvent: Codable, Equatable, Sendable {
        public var type = "error"
        public var code: String
        public var message: String?
        public var allowRetry: Bool

        public init(code: String = "custom", message: String? = nil, allowRetry: Bool = false) {
            self.code = code
            self.message = message
            self.allowRetry = allowRetry
        }
    }

    public struct Notice: Codable, Equatable, Identifiable, Sendable {
        public var type = "notice"
        public var level: Level
        public var message: String
        public var title: String?

        public var id: String {
            "\(level.rawValue)-\(title ?? "")-\(message)"
        }

        public init(level: Level, message: String, title: String? = nil) {
            self.level = level
            self.message = message
            self.title = title
        }

        public enum Level: String, Codable, Equatable, Sendable {
            case info
            case warning
            case danger
        }
    }
}

public enum ChatKitThreadItemUpdate: Codable, Equatable, Sendable {
    case assistantMessageContentPartAdded(AssistantMessageContentPartAdded)
    case assistantMessageContentPartTextDelta(AssistantMessageContentPartTextDelta)
    case assistantMessageContentPartAnnotationAdded(AssistantMessageContentPartAnnotationAdded)
    case assistantMessageContentPartDone(AssistantMessageContentPartDone)
    case widgetStreamingTextValueDelta(WidgetStreamingTextValueDelta)
    case widgetRootUpdated(WidgetRootUpdated)
    case widgetComponentUpdated(WidgetComponentUpdated)
    case workflowTaskAdded(GenericIndexedUpdate)
    case workflowTaskUpdated(GenericIndexedUpdate)
    case imageGenerationPreviewUpdated(ImageGenerationPreviewUpdated)
    case generatedImageUpdated(GeneratedImageUpdated)
    case unknown(type: String, raw: [String: JSONValue])

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        let type = raw["type"]?.stringValue ?? "unknown"
        let data = try JSONSerialization.data(withJSONObject: raw.foundationObject)

        switch type {
        case "assistant_message.content_part.added":
            self = try .assistantMessageContentPartAdded(ChatKitJSON.decoder.decode(AssistantMessageContentPartAdded.self, from: data))
        case "assistant_message.content_part.text_delta":
            self = try .assistantMessageContentPartTextDelta(ChatKitJSON.decoder.decode(AssistantMessageContentPartTextDelta.self, from: data))
        case "assistant_message.content_part.annotation_added":
            self = try .assistantMessageContentPartAnnotationAdded(ChatKitJSON.decoder.decode(AssistantMessageContentPartAnnotationAdded.self, from: data))
        case "assistant_message.content_part.done":
            self = try .assistantMessageContentPartDone(ChatKitJSON.decoder.decode(AssistantMessageContentPartDone.self, from: data))
        case "widget.streaming_text.value_delta":
            self = try .widgetStreamingTextValueDelta(ChatKitJSON.decoder.decode(WidgetStreamingTextValueDelta.self, from: data))
        case "widget.root.updated":
            self = try .widgetRootUpdated(ChatKitJSON.decoder.decode(WidgetRootUpdated.self, from: data))
        case "widget.component.updated":
            self = try .widgetComponentUpdated(ChatKitJSON.decoder.decode(WidgetComponentUpdated.self, from: data))
        case "workflow.task.added":
            self = try .workflowTaskAdded(ChatKitJSON.decoder.decode(GenericIndexedUpdate.self, from: data))
        case "workflow.task.updated":
            self = try .workflowTaskUpdated(ChatKitJSON.decoder.decode(GenericIndexedUpdate.self, from: data))
        case "image_generation.preview.updated":
            self = try .imageGenerationPreviewUpdated(ChatKitJSON.decoder.decode(ImageGenerationPreviewUpdated.self, from: data))
        case "generated_image.updated":
            self = try .generatedImageUpdated(ChatKitJSON.decoder.decode(GeneratedImageUpdated.self, from: data))
        default:
            self = .unknown(type: type, raw: raw.chatKitProtocolKeyedObject)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .assistantMessageContentPartAdded(value):
            try value.encode(to: encoder)
        case let .assistantMessageContentPartTextDelta(value):
            try value.encode(to: encoder)
        case let .assistantMessageContentPartAnnotationAdded(value):
            try value.encode(to: encoder)
        case let .assistantMessageContentPartDone(value):
            try value.encode(to: encoder)
        case let .widgetStreamingTextValueDelta(value):
            try value.encode(to: encoder)
        case let .widgetRootUpdated(value):
            try value.encode(to: encoder)
        case let .widgetComponentUpdated(value):
            try value.encode(to: encoder)
        case let .workflowTaskAdded(value), let .workflowTaskUpdated(value):
            try value.encode(to: encoder)
        case let .imageGenerationPreviewUpdated(value):
            try value.encode(to: encoder)
        case let .generatedImageUpdated(value):
            try value.encode(to: encoder)
        case let .unknown(type, raw):
            var encoded = raw
            encoded["type"] = .string(type)
            try encoded.encode(to: encoder)
        }
    }

    public struct AssistantMessageContentPartAdded: Codable, Equatable, Sendable {
        public var type = "assistant_message.content_part.added"
        public var contentIndex: Int
        public var content: ChatKitAssistantMessageContent
    }

    public struct AssistantMessageContentPartTextDelta: Codable, Equatable, Sendable {
        public var type = "assistant_message.content_part.text_delta"
        public var contentIndex: Int
        public var delta: String

        public init(contentIndex: Int, delta: String) {
            self.contentIndex = contentIndex
            self.delta = delta
        }
    }

    public struct AssistantMessageContentPartAnnotationAdded: Codable, Equatable, Sendable {
        public var type = "assistant_message.content_part.annotation_added"
        public var contentIndex: Int
        public var annotationIndex: Int
        public var annotation: ChatKitAnnotation
    }

    public struct AssistantMessageContentPartDone: Codable, Equatable, Sendable {
        public var type = "assistant_message.content_part.done"
        public var contentIndex: Int
        public var content: ChatKitAssistantMessageContent
    }

    public struct WidgetStreamingTextValueDelta: Codable, Equatable, Sendable {
        public var type = "widget.streaming_text.value_delta"
        public var componentID: String
        public var delta: String
        public var done: Bool

        private enum CodingKeys: String, CodingKey {
            case type
            case componentID = "componentId"
            case delta
            case done
        }
    }

    public struct WidgetRootUpdated: Codable, Equatable, Sendable {
        public var type = "widget.root.updated"
        public var widget: ChatKitWidgetNode
    }

    public struct WidgetComponentUpdated: Codable, Equatable, Sendable {
        public var type = "widget.component.updated"
        public var componentID: String
        public var component: ChatKitWidgetNode

        private enum CodingKeys: String, CodingKey {
            case type
            case componentID = "componentId"
            case component
        }
    }

    public struct GenericIndexedUpdate: Codable, Equatable, Sendable {
        public var type: String
        public var taskIndex: Int
        public var task: [String: JSONValue]
    }

    public struct ImageGenerationPreviewUpdated: Codable, Equatable, Sendable {
        public var type = "image_generation.preview.updated"
        public var image: ChatKitGeneratedImageItem.GeneratedImage
        public var progress: Double?

        public init(image: ChatKitGeneratedImageItem.GeneratedImage, progress: Double? = nil) {
            self.image = image
            self.progress = progress
        }
    }

    public struct GeneratedImageUpdated: Codable, Equatable, Sendable {
        public var type = "generated_image.updated"
        public var image: ChatKitGeneratedImageItem.GeneratedImage
        public var progress: Double?
    }
}
