import SwiftUI

/// Standalone native preview for a ``ChatKitWidgetNode``.
///
/// Use this in demo apps, test harnesses, and design tooling when you want to
/// render a widget payload without inserting it into a live ``ChatKitSession``.
public struct ChatKitWidgetPreview: View {
    private let item: ChatKitWidgetItem
    @State private var session: ChatKitSession

    @MainActor
    public init(
        widget: ChatKitWidgetNode,
        theme: ChatKitTheme = .init(),
        onAction: (@Sendable (ChatKitAction, ChatKitWidgetItem) async throws -> Void)? = nil,
    ) {
        item = .init(
            id: "preview_widget",
            threadID: "preview_thread",
            createdAt: Date(),
            widget: widget,
        )
        _session = State(initialValue: ChatKitSession(
            options: .init(
                api: .custom(url: URL(string: "https://example.invalid/chatkit")!),
                theme: theme,
                widgets: .init(onAction: onAction),
            ),
            transport: ChatKitWidgetPreviewTransport(),
        ))
    }

    public var body: some View {
        ChatKitWidgetView(item: item, session: session)
    }
}

private struct ChatKitWidgetPreviewTransport: ChatKitTransport {
    func send(_ request: ChatKitRequest) async throws -> Data {
        throw ChatKitTransportError.invalidPayload("Widget preview does not send ChatKit requests.")
    }

    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        throw ChatKitTransportError.invalidPayload("Widget preview does not stream ChatKit requests.")
    }
}
