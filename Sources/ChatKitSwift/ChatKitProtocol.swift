import Foundation

/// A paginated ChatKit response.
public struct ChatKitPage<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var data: [Element]
    public var hasMore: Bool
    public var after: String?

    public init(data: [Element] = [], hasMore: Bool = false, after: String? = nil) {
        self.data = data
        self.hasMore = hasMore
        self.after = after
    }
}

/// Sort order used by list requests.
public enum ChatKitOrder: String, Codable, Equatable, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

/// Encodable request envelope sent to a ChatKit-compatible backend.
///
/// The encoded JSON contains a `type` string such as `threads.create` and a `params`
/// object whose shape is defined by the associated request payload. ``isStreaming``
/// indicates whether ``ChatKitTransport/stream(_:)`` or ``ChatKitTransport/send(_:)``
/// should be used.
public enum ChatKitRequest: Encodable, Sendable {
    case threadsGetByID(ThreadsGetByID)
    case threadsCreate(ThreadsCreate)
    case threadsList(ThreadsList)
    case threadsAddUserMessage(ThreadsAddUserMessage)
    case threadsAddClientToolOutput(ThreadsAddClientToolOutput)
    case threadsAddStructuredInput(ThreadsAddStructuredInput)
    case threadsCustomAction(ThreadsCustomAction)
    case threadsSyncCustomAction(ThreadsCustomAction)
    case threadsRetryAfterItem(ThreadsRetryAfterItem)
    case threadsUpdate(ThreadsUpdate)
    case threadsDelete(ThreadsDelete)
    case itemsList(ItemsList)
    case itemsFeedback(ItemsFeedback)
    case attachmentsCreate(AttachmentsCreate)
    case attachmentsDelete(AttachmentsDelete)
    case inputTranscribe(InputTranscribe)

    public var type: String {
        switch self {
        case .threadsGetByID: "threads.get_by_id"
        case .threadsCreate: "threads.create"
        case .threadsList: "threads.list"
        case .threadsAddUserMessage: "threads.add_user_message"
        case .threadsAddClientToolOutput: "threads.add_client_tool_output"
        case .threadsAddStructuredInput: "threads.add_structured_input"
        case .threadsCustomAction: "threads.custom_action"
        case .threadsSyncCustomAction: "threads.sync_custom_action"
        case .threadsRetryAfterItem: "threads.retry_after_item"
        case .threadsUpdate: "threads.update"
        case .threadsDelete: "threads.delete"
        case .itemsList: "items.list"
        case .itemsFeedback: "items.feedback"
        case .attachmentsCreate: "attachments.create"
        case .attachmentsDelete: "attachments.delete"
        case .inputTranscribe: "input.transcribe"
        }
    }

    public var isStreaming: Bool {
        switch self {
        case .threadsCreate, .threadsAddUserMessage, .threadsAddClientToolOutput, .threadsAddStructuredInput, .threadsCustomAction, .threadsRetryAfterItem:
            true
        case .threadsGetByID, .threadsList, .threadsSyncCustomAction, .threadsUpdate, .threadsDelete, .itemsList, .itemsFeedback, .attachmentsCreate, .attachmentsDelete, .inputTranscribe:
            false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .threadsGetByID(params):
            try container.encode(params, forKey: .params)
        case let .threadsCreate(params):
            try container.encode(params, forKey: .params)
        case let .threadsList(params):
            try container.encode(params, forKey: .params)
        case let .threadsAddUserMessage(params):
            try container.encode(params, forKey: .params)
        case let .threadsAddClientToolOutput(params):
            try container.encode(params, forKey: .params)
        case let .threadsAddStructuredInput(params):
            try container.encode(params, forKey: .params)
        case let .threadsCustomAction(params), let .threadsSyncCustomAction(params):
            try container.encode(params, forKey: .params)
        case let .threadsRetryAfterItem(params):
            try container.encode(params, forKey: .params)
        case let .threadsUpdate(params):
            try container.encode(params, forKey: .params)
        case let .threadsDelete(params):
            try container.encode(params, forKey: .params)
        case let .itemsList(params):
            try container.encode(params, forKey: .params)
        case let .itemsFeedback(params):
            try container.encode(params, forKey: .params)
        case let .attachmentsCreate(params):
            try container.encode(params, forKey: .params)
        case let .attachmentsDelete(params):
            try container.encode(params, forKey: .params)
        case let .inputTranscribe(params):
            try container.encode(params, forKey: .params)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case params
    }

    public struct ThreadsGetByID: Codable, Equatable, Sendable {
        public var threadID: String

        public init(threadID: String) {
            self.threadID = threadID
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
        }
    }

    public struct ThreadsCreate: Codable, Equatable, Sendable {
        public var input: ChatKitUserMessageInput

        public init(input: ChatKitUserMessageInput) {
            self.input = input
        }
    }

    public struct ThreadsList: Codable, Equatable, Sendable {
        public var limit: Int?
        public var order: ChatKitOrder
        public var after: String?

        public init(limit: Int? = nil, order: ChatKitOrder = .descending, after: String? = nil) {
            self.limit = limit
            self.order = order
            self.after = after
        }
    }

    public struct ThreadsAddUserMessage: Codable, Equatable, Sendable {
        public var input: ChatKitUserMessageInput
        public var threadID: String

        public init(input: ChatKitUserMessageInput, threadID: String) {
            self.input = input
            self.threadID = threadID
        }

        private enum CodingKeys: String, CodingKey {
            case input
            case threadID = "threadId"
        }
    }

    public struct ThreadsAddClientToolOutput: Codable, Equatable, Sendable {
        public var threadID: String
        public var result: JSONValue

        public init(threadID: String, result: JSONValue) {
            self.threadID = threadID
            self.result = result
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case result
        }
    }

    public struct ThreadsAddStructuredInput: Codable, Equatable, Sendable {
        public var threadID: String
        public var itemID: String
        public var input: ChatKitStructuredInputSubmission

        public init(threadID: String, itemID: String, input: ChatKitStructuredInputSubmission) {
            self.threadID = threadID
            self.itemID = itemID
            self.input = input
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case itemID = "itemId"
            case input
        }
    }

    public struct ThreadsCustomAction: Codable, Equatable, Sendable {
        public var threadID: String
        public var itemID: String?
        public var action: ChatKitAction

        public init(threadID: String, itemID: String? = nil, action: ChatKitAction) {
            self.threadID = threadID
            self.itemID = itemID
            self.action = action
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case itemID = "itemId"
            case action
        }
    }

    public struct ThreadsRetryAfterItem: Codable, Equatable, Sendable {
        public var threadID: String
        public var itemID: String

        public init(threadID: String, itemID: String) {
            self.threadID = threadID
            self.itemID = itemID
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case itemID = "itemId"
        }
    }

    public struct ThreadsUpdate: Codable, Equatable, Sendable {
        public var threadID: String
        public var title: String

        public init(threadID: String, title: String) {
            self.threadID = threadID
            self.title = title
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case title
        }
    }

    public struct ThreadsDelete: Codable, Equatable, Sendable {
        public var threadID: String

        public init(threadID: String) {
            self.threadID = threadID
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
        }
    }

    public struct ItemsList: Codable, Equatable, Sendable {
        public var threadID: String
        public var limit: Int?
        public var order: ChatKitOrder
        public var after: String?

        public init(threadID: String, limit: Int? = nil, order: ChatKitOrder = .ascending, after: String? = nil) {
            self.threadID = threadID
            self.limit = limit
            self.order = order
            self.after = after
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case limit
            case order
            case after
        }
    }

    public struct ItemsFeedback: Codable, Equatable, Sendable {
        public var threadID: String
        public var itemIDs: [String]
        public var kind: ChatKitFeedbackKind

        public init(threadID: String, itemIDs: [String], kind: ChatKitFeedbackKind) {
            self.threadID = threadID
            self.itemIDs = itemIDs
            self.kind = kind
        }

        private enum CodingKeys: String, CodingKey {
            case threadID = "threadId"
            case itemIDs = "itemIds"
            case kind
        }
    }

    public struct AttachmentsCreate: Codable, Equatable, Sendable {
        public var name: String
        public var size: Int
        public var mimeType: String

        public init(name: String, size: Int, mimeType: String) {
            self.name = name
            self.size = size
            self.mimeType = mimeType
        }
    }

    public struct AttachmentsDelete: Codable, Equatable, Sendable {
        public var attachmentID: String

        public init(attachmentID: String) {
            self.attachmentID = attachmentID
        }

        private enum CodingKeys: String, CodingKey {
            case attachmentID = "attachmentId"
        }
    }

    public struct InputTranscribe: Codable, Equatable, Sendable {
        public var audioBase64: String
        public var mimeType: String

        public init(audioBase64: String, mimeType: String) {
            self.audioBase64 = audioBase64
            self.mimeType = mimeType
        }
    }
}

public enum ChatKitFeedbackKind: String, Codable, Equatable, Sendable {
    case positive
    case negative
}
