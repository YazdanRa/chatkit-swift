import Foundation

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
        selectedModelID: String? = nil
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
