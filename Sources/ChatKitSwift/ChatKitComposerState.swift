import Foundation

/// Selection update for ``ChatKitSession/setComposerValue``.
///
/// JavaScript ChatKit distinguishes an omitted `selectedToolId` from an explicit
/// `null`. Swift optionals collapse those states, so this enum preserves the same
/// semantics: omit the argument to leave the tool unchanged, pass `nil` to clear it,
/// or pass a string value to select a tool.
public enum ChatKitSelectedToolID: Equatable, Sendable, ExpressibleByStringLiteral {
    case unchanged
    case value(String)

    public init(stringLiteral value: String) {
        self = .value(value)
    }
}

public struct ChatKitComposerState: Equatable, Sendable {
    public var text: String
    public var content: [ChatKitUserMessageContent]
    public var reply: String?
    public var attachments: [ChatKitAttachment]
    public var files: [ChatKitLocalFile]
    public var selectedToolID: String?
    public var selectedModelID: String?

    public init(
        text: String = "",
        content: [ChatKitUserMessageContent] = [],
        reply: String? = nil,
        attachments: [ChatKitAttachment] = [],
        files: [ChatKitLocalFile] = [],
        selectedToolID: String? = nil,
        selectedModelID: String? = nil,
    ) {
        self.text = text
        self.content = content
        self.reply = reply
        self.attachments = attachments
        self.files = files
        self.selectedToolID = selectedToolID
        self.selectedModelID = selectedModelID
    }
}
