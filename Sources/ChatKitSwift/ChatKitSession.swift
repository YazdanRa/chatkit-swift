import Foundation
import Observation

/// Main-actor controller for ChatKit conversation state and imperative actions.
///
/// `ChatKitSession` owns the current ``ChatKitConversationState``, composer state,
/// history visibility, and transport. SwiftUI views observe it directly, while host
/// UI can call its methods to load threads, send messages, retry responses, submit
/// structured inputs, and report feedback.
@Observable
@MainActor
public final class ChatKitSession {
    public private(set) var options: ChatKitOptions
    public private(set) var state: ChatKitConversationState
    public var composer: ChatKitComposerState
    public private(set) var isHistoryVisible: Bool
    public private(set) var composerFocusRequestID: UUID

    @ObservationIgnored private let transport: any ChatKitTransport

    /// Creates a session with the provided options and optional transport.
    ///
    /// When `transport` is omitted, the session uses ``ChatKitHTTPTransport`` with
    /// `options.api`. If `options.initialThread` is set, the session starts loading
    /// that thread after initialization.
    public init(options: ChatKitOptions, transport: (any ChatKitTransport)? = nil) {
        self.options = options
        self.transport = transport ?? ChatKitHTTPTransport(api: options.api)
        state = .init()
        composer = .init(selectedModelID: options.composer.models.first(where: \.isDefault)?.id)
        isHistoryVisible = false
        composerFocusRequestID = UUID()

        if let initialThread = options.initialThread {
            Task { try? await setThreadId(initialThread) }
        }
        options.events.onReady?()
    }

    /// Replaces session options used for future requests and rendering.
    ///
    /// Existing conversation state is preserved. If the API mode changes, create a
    /// new session so the default transport is rebuilt with the new configuration.
    public func setOptions(_ options: ChatKitOptions) {
        self.options = options
        options.events.onReady?()
    }

    /// Requests focus for the composer in any attached ``ChatKitView``.
    public func focusComposer() async {
        composerFocusRequestID = UUID()
    }

    /// Loads a thread by ID, or clears the current thread when `threadID` is `nil`.
    ///
    /// Loading emits `onThreadLoadStart`, `onThreadLoadEnd`, and `onThreadChange`
    /// callbacks from ``ChatKitEventHandlers``.
    public func setThreadId(_ threadID: String?) async throws {
        guard let threadID else {
            state = .init(threads: state.threads)
            options.events.onThreadChange?(nil)
            return
        }

        options.events.onThreadLoadStart?(threadID)
        defer { options.events.onThreadLoadEnd?(threadID) }

        let data = try await transport.send(.threadsGetByID(.init(threadID: threadID)))
        let thread = try ChatKitJSON.decoder.decode(ChatKitThread.self, from: data)
        state.replaceCurrentThread(thread)
        options.events.onThreadChange?(threadID)
    }

    /// Loads the thread list into ``state``.
    ///
    /// - Parameters:
    ///   - limit: Optional maximum number of threads to request.
    ///   - order: Sort order understood by the backend.
    ///   - after: Optional pagination cursor.
    public func loadThreads(limit: Int? = nil, order: ChatKitOrder = .descending, after: String? = nil) async throws {
        let data = try await transport.send(.threadsList(.init(limit: limit, order: order, after: after)))
        let page = try ChatKitJSON.decoder.decode(ChatKitPage<ChatKitThread>.self, from: data)
        state.replaceThreads(page.data)
    }

    /// Refreshes items for the current thread.
    ///
    /// If there is no active thread, this method returns without making a request.
    public func fetchUpdates() async throws {
        guard let threadID = state.currentThread?.id else {
            return
        }

        let data = try await transport.send(.itemsList(.init(threadID: threadID)))
        let page = try ChatKitJSON.decoder.decode(ChatKitPage<ChatKitThreadItem>.self, from: data)
        state.replaceItems(page.data)
    }

    /// Sends a user message and streams the backend response into session state.
    ///
    /// If `content` is omitted, the method sends `text` or the current composer text
    /// as a single ``ChatKitUserMessageContent/inputText(_:)`` part. When `newThread`
    /// is true, or no current thread exists, the request creates a thread. Otherwise
    /// it appends to the current thread. The composer text is cleared before the
    /// streamed response starts.
    public func sendUserMessage(
        text: String? = nil,
        content: [ChatKitUserMessageContent]? = nil,
        reply: String? = nil,
        attachments: [ChatKitAttachment] = [],
        newThread: Bool = false,
        toolChoice: ChatKitToolChoice? = nil,
        model: String? = nil,
    ) async throws {
        let messageContent = content ?? [ChatKitUserMessageContent.inputText(.init(text: text ?? composer.text))]
        let attachmentIDs = attachments.map(\.id)
        let input = ChatKitUserMessageInput(
            content: messageContent,
            attachments: attachmentIDs,
            quotedText: reply,
            inferenceOptions: .init(toolChoice: toolChoice ?? selectedToolChoice, model: model ?? composer.selectedModelID),
        )
        let request: ChatKitRequest
        if newThread || state.currentThread == nil {
            request = .threadsCreate(.init(input: input))
        } else if let threadID = state.currentThread?.id {
            request = .threadsAddUserMessage(.init(input: input, threadID: threadID))
        } else {
            throw ChatKitTransportError.missingCurrentThread
        }

        state.addOptimisticUserMessage(
            id: "local_\(UUID().uuidString)",
            threadID: state.currentThread?.id ?? "local_thread",
            createdAt: Date(),
            input: input,
            attachments: attachments,
        )
        composer.text = ""
        composer.content = []
        if options.composer.tools.first(where: { $0.id == composer.selectedToolID })?.persistent != true {
            composer.selectedToolID = nil
        }
        try await runStream(request)
    }

    /// Updates composer state from host UI.
    ///
    /// Use this to prefill text, attach files, set rich content, or select a tool or
    /// model before the user sends a message.
    public func setComposerValue(
        text: String? = nil,
        content: [ChatKitUserMessageContent]? = nil,
        reply: String? = nil,
        attachments: [ChatKitAttachment]? = nil,
        files: [ChatKitLocalFile]? = nil,
        selectedToolID: String? = nil,
        selectedModelID: String? = nil,
    ) async {
        if let text {
            composer.text = text
        }
        if let content {
            composer.content = content
        }
        if let reply {
            composer.reply = reply
        }
        if let attachments {
            composer.attachments = attachments
        }
        if let files {
            composer.files = files
        }
        composer.selectedToolID = selectedToolID
        if let selectedModelID {
            composer.selectedModelID = selectedModelID
        }
        options.events.onToolChange?(composer.selectedToolID)
    }

    /// Sends a widget or custom action for the current thread.
    ///
    /// Throws ``ChatKitTransportError/missingCurrentThread`` when no thread is active.
    public func sendCustomAction(_ action: ChatKitAction, itemID: String? = nil) async throws {
        guard let threadID = state.currentThread?.id else {
            throw ChatKitTransportError.missingCurrentThread
        }

        try await runStream(.threadsCustomAction(.init(threadID: threadID, itemID: itemID, action: action)))
    }

    /// Submits answers for a structured input item.
    ///
    /// The `itemID` should identify the structured input item being answered.
    public func submitStructuredInput(_ submission: ChatKitStructuredInputSubmission, itemID: String) async throws {
        guard let threadID = state.currentThread?.id else {
            throw ChatKitTransportError.missingCurrentThread
        }

        try await runStream(.threadsAddStructuredInput(.init(threadID: threadID, itemID: itemID, input: submission)))
    }

    /// Retries generation after a specific thread item.
    public func retry(after itemID: String) async throws {
        guard let threadID = state.currentThread?.id else {
            throw ChatKitTransportError.missingCurrentThread
        }

        try await runStream(.threadsRetryAfterItem(.init(threadID: threadID, itemID: itemID)))
    }

    /// Sends feedback for one or more items in the current thread.
    public func addFeedback(itemIDs: [String], kind: ChatKitFeedbackKind) async throws {
        guard let threadID = state.currentThread?.id else {
            throw ChatKitTransportError.missingCurrentThread
        }

        _ = try await transport.send(.itemsFeedback(.init(threadID: threadID, itemIDs: itemIDs, kind: kind)))
    }

    /// Updates the title of the current thread and replaces it in session state.
    public func updateCurrentThreadTitle(_ title: String) async throws {
        guard let threadID = state.currentThread?.id else {
            throw ChatKitTransportError.missingCurrentThread
        }

        let data = try await transport.send(.threadsUpdate(.init(threadID: threadID, title: title)))
        let thread = try ChatKitJSON.decoder.decode(ChatKitThread.self, from: data)
        state.replaceCurrentThread(thread)
    }

    /// Deletes a thread and clears current state if it was active.
    public func deleteThread(_ threadID: String) async throws {
        _ = try await transport.send(.threadsDelete(.init(threadID: threadID)))
        state.threads.removeAll { $0.id == threadID }
        if state.currentThread?.id == threadID {
            state = .init(threads: state.threads)
        }
    }

    /// Shows the built-in history UI when history is enabled.
    public func showHistory() async {
        isHistoryVisible = true
    }

    /// Hides the built-in history UI.
    public func hideHistory() async {
        isHistoryVisible = false
    }

    private var selectedToolChoice: ChatKitToolChoice? {
        composer.selectedToolID.map(ChatKitToolChoice.init(id:))
    }

    private func runStream(_ request: ChatKitRequest) async throws {
        options.events.onResponseStart?()
        state.isResponding = true

        do {
            let stream = try await transport.stream(request)
            for try await event in stream {
                await handle(event)
            }
            state.isResponding = false
            options.events.onResponseEnd?()
        } catch {
            state.apply(.error(.init(code: "transport_error", message: error.localizedDescription, allowRetry: true)))
            options.events.onError?(state.error ?? .init(code: "transport_error", message: error.localizedDescription, allowRetry: true))
            options.events.onResponseEnd?()
            throw error
        }
    }

    private func handle(_ event: ChatKitEvent) async {
        state.apply(event)
        emitCallback(for: event)

        if case let .threadItemDone(done) = event,
           case let .clientToolCall(toolCall) = done.item,
           toolCall.status == "pending"
        {
            await fulfillClientToolCall(toolCall)
        }
    }

    private func fulfillClientToolCall(_ toolCall: ChatKitClientToolCallItem) async {
        guard let handler = options.onClientTool else {
            return
        }

        do {
            let result = try await handler(.init(name: toolCall.name, params: toolCall.arguments))
            try await runStream(.threadsAddClientToolOutput(.init(threadID: toolCall.threadID, result: .object(result))))
        } catch {
            state.apply(.error(.init(code: "client_tool_error", message: error.localizedDescription, allowRetry: true)))
        }
    }

    private func emitCallback(for event: ChatKitEvent) {
        switch event {
        case let .threadCreated(event):
            options.events.onThreadChange?(event.thread.id)
        case let .threadUpdated(event):
            options.events.onThreadChange?(event.thread.id)
        case let .error(event):
            options.events.onError?(event)
        case let .clientEffect(event):
            options.events.onEffect?(event.name, event.data)
            if event.name == "deeplink" {
                options.events.onDeeplink?(event.name, event.data)
            }
        default:
            break
        }
    }
}
