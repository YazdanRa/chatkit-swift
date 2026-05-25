# ChatKitSwift

> [!CAUTION]
> This project is still in early stages and under heavy development. Anything and everything can change. Most of the code is AI generated and hasn't been fully reviewed yet!

ChatKitSwift is a native SwiftUI client for OpenAI ChatKit. It mirrors the client concepts from [openai/chatkit-js](https://github.com/openai/chatkit-js) while using SwiftUI views, Swift concurrency, `Observation`, and Swift Package Manager.

The package provides:

- `ChatKitView`, an embeddable SwiftUI chat surface.
- `ChatKitSession`, a main-actor controller for imperative actions and state.
- Codable models for the ChatKit request, response, thread, item, widget, and event protocol.
- HTTP and server-sent event transport for custom or hosted ChatKit backends.
- Native configuration for header, history, start screen, composer tools, models, entities, widgets, feedback, retry, theme, and event callbacks.

## Requirements

- Swift 6.3 or newer
- Xcode with Swift 6.3 toolchain support
- iOS 18, macOS 15, or visionOS 2
- A backend endpoint that implements the ChatKit protocol and keeps OpenAI API keys server-side

The repository root is the Swift package root.

## Installation

### Xcode

1. Choose `File > Add Package Dependencies`.
2. Enter the package URL:

   ```text
   https://github.com/YazdanRa/chatkit-swift.git
   ```

3. Select the released version rule, starting from `1.1.0`.
4. Add the `ChatKitSwift` library product to your app target.

### Swift Package Manager

Add the released GitHub package to your `Package.swift` dependencies:

```swift
.dependencies([
    .package(url: "https://github.com/YazdanRa/chatkit-swift.git", from: "1.1.0")
])
```

Then add the `ChatKitSwift` product to the target that owns your chat UI:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ChatKitSwift", package: "chatkit-swift")
    ]
)
```

The Swift package identity is `chatkit-swift`, while the package name, library
product, and importable module are `ChatKitSwift`.

For local development against a checkout of this repository, use a path
dependency instead:

```swift
.dependencies([
    .package(path: "../chatkit-swift")
])
```

## Quick Start

```swift
import ChatKitSwift
import Foundation
import SwiftUI

struct ChatScreen: View {
    var body: some View {
        ChatKitView(options: options)
    }

    private var options: ChatKitOptions {
        ChatKitOptions(
            api: .custom(
                url: URL(string: "https://yourapp.example.com/api/chatkit")!
            ),
            frameTitle: "Assistant",
            startScreen: .init(
                greeting: "What can I help with today?",
                prompts: [
                    .init(
                        label: "Summarize this project",
                        prompt: .text("Summarize this project.")
                    )
                ]
            ),
            composer: .init(
                placeholder: "Message the assistant",
                tools: [
                    .init(
                        id: "search",
                        label: "Search",
                        icon: "magnifyingglass",
                        pinned: true
                    )
                ],
                models: [
                    .init(id: "gpt-5.1", label: "GPT-5.1", isDefault: true)
                ]
            ),
            threadItemActions: .init(feedback: true, retry: true),
            thread: .init(autoScroll: true),
            events: .init(
                onError: { error in
                    print(error.message ?? error.code)
                },
                onThreadChange: { threadID in
                    print("Thread:", threadID ?? "none")
                }
            )
        )
    }
}
```

`ChatKitView(options:)` owns its own `ChatKitSession`. Use this for static configuration. If the app needs to drive the conversation from outside the view, create and inject a session.

```swift
import ChatKitSwift
import Foundation
import SwiftUI

@MainActor
struct ControlledChatScreen: View {
    @State private var session: ChatKitSession

    init() {
        let options = ChatKitOptions(
            api: .custom(url: URL(string: "https://yourapp.example.com/api/chatkit")!)
        )
        _session = State(initialValue: ChatKitSession(options: options))
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatKitView(session: session)

            Button("New thread") {
                Task {
                    try await session.setThreadId(nil)
                    try await session.sendUserMessage(
                        text: "Start a new conversation",
                        newThread: true
                    )
                }
            }
        }
    }
}
```

## Backend Contract

ChatKitSwift sends JSON requests shaped like the ChatKit protocol:

```json
{
  "type": "threads.create",
  "params": {
    "input": {
      "content": [{ "type": "input_text", "text": "Hello" }],
      "attachments": [],
      "inference_options": {}
    }
  }
}
```

Non-streaming requests should return JSON for the requested resource. Streaming requests should return `text/event-stream`, where each event payload is a ChatKit event:

```text
data: {"type":"thread.created","thread":{"id":"thread_123","title":"New chat","created_at":"2026-05-23T00:00:00Z","status":{"type":"active"},"items":{"data":[],"has_more":false}}}

data: {"type":"thread.item.done","item":{"type":"assistant_message","id":"msg_123","thread_id":"thread_123","created_at":"2026-05-23T00:00:01Z","content":[{"type":"output_text","text":"Hello","annotations":[]}]}}
```

The built-in transport posts every request to the configured endpoint. Streaming methods use the same endpoint with `Accept: text/event-stream`.

Supported request types include:

- `threads.get_by_id`
- `threads.create`
- `threads.list`
- `threads.add_user_message`
- `threads.add_client_tool_output`
- `threads.add_structured_input`
- `threads.custom_action`
- `threads.sync_custom_action`
- `threads.retry_after_item`
- `threads.update`
- `threads.delete`
- `items.list`
- `items.feedback`
- `attachments.create`
- `attachments.delete`
- `input.transcribe`

Do not put an OpenAI API key in an iOS, macOS, or visionOS app. The recommended production setup is a custom backend endpoint that validates the user, calls OpenAI server-side, and streams ChatKit events back to the app.

## API Configuration

Use `.custom` for your own backend:

```swift
let options = ChatKitOptions(
    api: .custom(
        url: URL(string: "https://yourapp.example.com/api/chatkit")!,
        domainKey: "optional-domain-key",
        additionalHeaders: {
            let token = try await AuthTokenProvider.shared.token()
            return ["Authorization": "Bearer \(token)"]
        }
    )
)
```

Use `.hosted` only when your server can mint and refresh short-lived ChatKit client secrets:

```swift
private struct ClientSecretResponse: Decodable {
    var clientSecret: String
}

let options = ChatKitOptions(
    api: .hosted { currentClientSecret in
        var request = URLRequest(
            url: URL(string: "https://yourapp.example.com/api/chatkit/session")!
        )

        if let currentClientSecret {
            request.setValue(currentClientSecret, forHTTPHeaderField: "X-Current-Client-Secret")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ClientSecretResponse.self, from: data).clientSecret
    }
)
```

## Configuration

`ChatKitOptions` is the main configuration surface.

The examples below assume:

```swift
let chatEndpoint = URL(string: "https://yourapp.example.com/api/chatkit")!
```

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    locale: Locale.current.identifier,
    theme: .init(
        colorScheme: .system,
        radius: .round,
        density: .normal,
        color: .init(
            accent: .init(primary: "#2563EB", level: 600)
        )
    ),
    frameTitle: "Support",
    initialThread: nil,
    header: .init(
        title: .init(text: "Support"),
        leftAction: .init(
            icon: "sidebar.left",
            accessibilityLabel: "Show history",
            perform: {}
        )
    ),
    history: .init(enabled: true, showDelete: true, showRename: true),
    startScreen: .init(
        greeting: "How can we help?",
        prompts: [
            .init(label: "Open tickets", prompt: .text("Show my open tickets."))
        ]
    ),
    threadItemActions: .init(feedback: true, retry: true),
    composer: .init(
        placeholder: "Ask support",
        attachments: .init(enabled: true, onRequest: {
            // Present your app's file picker, then call session.setComposerValue(...)
        }),
        tools: [.init(id: "tickets", label: "Tickets", icon: "tray.full", pinned: true)],
        models: [.init(id: "fast", label: "Fast", isDefault: true)],
        dictation: .init(enabled: true)
    ),
    disclaimer: .init(text: "AI can make mistakes. Verify critical information."),
    thread: .init(autoScroll: true)
)
```

Icon values are SF Symbol names.

### Events

Use event handlers for lifecycle, errors, thread changes, tool changes, and effects.

```swift
let events = ChatKitEventHandlers(
    onReady: {
        print("ChatKit ready")
    },
    onResponseStart: {
        print("Assistant started responding")
    },
    onResponseEnd: {
        print("Assistant finished responding")
    },
    onError: { error in
        print(error.code, error.message ?? "")
    },
    onThreadChange: { threadID in
        print(threadID ?? "No thread")
    },
    onEffect: { name, data in
        print(name, data ?? [:])
    }
)
```

### Client Tools

When the backend emits a pending `client_tool_call` item, ChatKitSwift calls `onClientTool` and sends the result back through `threads.add_client_tool_output`.

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    onClientTool: { call in
        switch call.name {
        case "current_location":
            return [
                "city": .string("Toronto"),
                "country": .string("Canada")
            ]
        default:
            return ["error": .string("Unknown client tool")]
        }
    }
)
```

### Entities

Entities power tag search and rich mentions in the composer.

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    entities: .init(
        onTagSearch: { query in
            [
                ChatKitEntity(
                    title: "Roadmap",
                    id: "doc_roadmap",
                    icon: "doc.text",
                    group: "Documents"
                )
            ].filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        },
        showComposerMenu: true,
        onClick: { entity in
            print("Selected", entity.id)
        },
        onRequestPreview: { entity in
            ChatKitWidgetNode(
                type: "Card",
                raw: [
                    "title": .string(entity.title),
                    "children": .array([
                        .object([
                            "type": .string("Text"),
                            "value": .string("Preview content")
                        ])
                    ])
                ]
            )
        }
    )
)
```

### Widgets

Widget payloads are decoded as `ChatKitWidgetNode`, preserving unknown fields in `raw` so the client can render known nodes and remain forward-compatible with newer protocol fields.
ChatKitSwift renders the official ChatKit widget component set natively in SwiftUI, including cards, list views, text, markdown, badges, icons, images, buttons, layout rows/columns, dividers, spacers, inputs, text areas, selects, date pickers, checkboxes, radio groups, labels, tables, table rows, table cells, and transitions. OpenAI widget icon names are translated to SF Symbols, while semantic widget colors and light/dark theme color objects are translated to native SwiftUI colors.

The official JavaScript package does not currently expose a dedicated `Chart` widget component. ChatKitSwift still includes a small native bar-chart renderer for chart-like payloads that use `Chart` or `BarChart` with `data`/`points` arrays, so custom backends can display simple native charts without falling back to raw JSON.

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    widgets: .init(
        onAction: { action, item in
            print("Widget action:", action.type, "from item:", item.id)
        }
    )
)
```

## Driving a Session

`ChatKitSession` is `@Observable` and `@MainActor`. Its public state includes the current conversation state, composer state, and history visibility.

```swift
try await session.loadThreads(limit: 20)
try await session.setThreadId("thread_123")
try await session.fetchUpdates()
try await session.sendUserMessage(text: "Continue this thread")
try await session.retry(after: "item_123")
try await session.addFeedback(itemIDs: ["item_123"], kind: .positive)
try await session.updateCurrentThreadTitle("Planning")
try await session.deleteThread("thread_123")
await session.showHistory()
await session.hideHistory()
```

To prefill composer state:

```swift
await session.setComposerValue(
    text: "Draft message",
    selectedToolID: "search",
    selectedModelID: "gpt-5.1"
)
```

## Custom Transport

Inject a custom transport for tests, previews, local fixtures, or a backend that does not use the default single-endpoint HTTP shape.

```swift
struct PreviewTransport: ChatKitTransport {
    func send(_ request: ChatKitRequest) async throws -> Data {
        Data("{}".utf8)
    }

    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                .threadCreated(
                    .init(
                        thread: .init(
                            title: "Preview",
                            id: "thread_preview",
                            createdAt: Date(),
                            items: .init()
                        )
                    )
                )
            )
            continuation.finish()
        }
    }
}

ChatKitView(
    options: ChatKitOptions(api: .custom(url: URL(string: "https://example.com")!)),
    transport: PreviewTransport()
)
```

## Attachments and Dictation

The package models attachments, local file state, attachment request types, and dictation configuration. Host apps still own platform permission flows, file picking, audio capture, upload byte transfer, and backend storage policy. Use `AttachmentConfiguration.onRequest` to present the host file picker, then pass `ChatKitAttachment` values into the session when sending messages. The protocol request sends their IDs.

## Development

From the repository root:

```bash
swift test -Xswiftc -warnings-as-errors
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, project conventions, and the pull request checklist.
