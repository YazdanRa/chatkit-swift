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
- `attachments.process`
- `attachments.get_preview`
- `attachments.delete`
- `input.transcribe`

Do not put an OpenAI API key in an iOS, macOS, or visionOS app. The recommended production setup is a custom backend endpoint that validates the user, calls OpenAI server-side, and streams ChatKit events back to the app.

## ChatKit.js 1.7.0 Parity

This package is derived from the `@openai/chatkit` 1.7.0 client concepts, but it is a native SwiftUI implementation rather than a web component in an iframe. The table below maps the public JS type surface to the current Swift surface.

| JS surface | Swift status | Notes |
| --- | --- | --- |
| `ChatKitOptions.api.custom.url` | Supported | `ChatKitAPI.custom(url:domainKey:uploadStrategy:additionalHeaders:)` posts ChatKit envelopes to one backend endpoint. |
| `api.custom.domainKey` | Supported | Sent as `OpenAI-Domain-Key` by the built-in transport for custom backends that require one. |
| `api.custom.fetch` | Native-only alternative | Inject a custom `ChatKitTransport` instead of a JS `fetch` override. |
| `api.custom.uploadStrategy` | Modeled | `ChatKitUploadStrategy` is exposed for host upload policy; file bytes are still owned by the host app. |
| `api.hosted.getClientSecret` | Supported | `ChatKitAPI.hosted(getClientSecret:endpoint:)` refreshes short-lived client secrets. Mint them on your server. |
| `locale` | Modeled, not localized | Stored on `ChatKitOptions`; built-in SwiftUI copy is currently English. |
| `theme.colorScheme` | Supported | Applies SwiftUI preferred color scheme. Swift adds `.system`; JS 1.7.0 exposes `light` and `dark`. |
| `theme.color.surface` | Supported | Applies top-level chat background and foreground colors. |
| `theme.color.accent`, `grayscale`, `radius`, `density`, `typography` | Modeled, partially applied | Values are part of `ChatKitTheme` and the demo controls, but the native view tree does not yet globally restyle every control from them. |
| `frameTitle` | Supported | Used for accessibility and demo navigation title. |
| `initialThread` | Supported | Loads a thread on session initialization; `nil` starts a new thread. |
| `onClientTool` | Supported | Swift callback receives `id`, `callID`, `name`, and `params`; output requests include `item_id` and `call_id` for backend correlation. |
| `header.enabled`, `title`, custom actions | Supported | JS custom button aliases map to `Header.leftAction` and `rightAction` with SF Symbol names. |
| `history.enabled`, `showDelete`, `showRename` | Supported | Native history supports load, select, delete, and editable rename. |
| `startScreen.greeting`, `prompts` | Supported | Prompts send text or structured content. |
| `threadItemActions.feedback`, `retry` | Supported | Feedback posts `items.feedback`; retry streams `threads.retry_after_item`. |
| `composer.placeholder` | Supported | Placeholder is rendered in the native composer. |
| `composer.attachments` | Supported for uploaded attachments | Attachment button calls the host `onRequest`; send requests include uploaded attachment IDs. `maxCount` gates the native composer, while `maxSize` and `accept` are exposed for host picker/upload enforcement. Swift models `attachments.create`, `attachments.process`, `attachments.get_preview`, and `attachments.delete` for custom backends. |
| `composer.tools` | Supported | Tool menu, pinned tools, placeholder override, and persistent selection behavior are implemented. |
| `composer.models` | Supported | Model selection updates composer inference options; disabled options are visible but not selectable. |
| `composer.dictation` | Modeled, native-scoped | Configuration exists; microphone permission, audio capture, and transcription UI are host-owned. |
| `disclaimer` | Supported | Renders markdown-like disclaimer text below the composer. |
| `entities.onTagSearch`, `showComposerMenu`, `onClick`, `onRequestPreview` | Partially supported | Tag search and composer insertion are implemented. Entity click/preview hooks are modeled for host integrations; full JS-style preview behavior remains scoped. |
| `widgets.onAction` | Supported | Native widget controls call `widgets.onAction` or fall back to `threads.custom_action`. |
| `thread.autoScroll` | Supported | Auto-scrolls near-bottom message lists while streaming. |
| `setOptions(options)` | Supported | `ChatKitSession.setOptions(_:)` replaces options; callers should pass the full intended configuration. |
| `focusComposer()` | Supported | `await session.focusComposer()` requests composer focus. |
| `setThreadId(threadId)` | Supported | `try await session.setThreadId(_:)`; pass `nil` for a new thread view. |
| `sendCustomAction(action, itemId)` | Supported | `try await session.sendCustomAction(_:itemID:)`. |
| `sendUserMessage(params)` | Supported | `try await session.sendUserMessage(...)` supports text, structured content, reply, uploaded attachments, new thread, tool choice, and model. |
| `setComposerValue(params)` | Supported | `await session.setComposerValue(...)`; omitted `selectedToolID` preserves selection and explicit `nil` clears it, matching JS `selectedToolId?: string \| null`. |
| `showHistory()` / `hideHistory()` | Supported | `await session.showHistory()` and `await session.hideHistory()`. |
| `fetchUpdates()` | Supported | `try await session.fetchUpdates()` reloads current thread items. |
| `addEventListener` / `removeEventListener` | Native-only alternative | Use `ChatKitEventHandlers` closures instead of DOM events. |
| `chatkit.ready` | Supported | `events.onReady`. |
| `chatkit.error` | Supported | `events.onError`. |
| `chatkit.effect` | Supported | `events.onEffect`. |
| `chatkit.deeplink` | Supported | `events.onDeeplink`. |
| `chatkit.response.start` / `chatkit.response.end` | Supported | `events.onResponseStart` and `events.onResponseEnd`. |
| `chatkit.thread.change` | Supported | `events.onThreadChange`. |
| `chatkit.thread.load.start` / `chatkit.thread.load.end` | Supported | `events.onThreadLoadStart` and `events.onThreadLoadEnd`. |
| `chatkit.tool.change` | Supported | `events.onToolChange`. |
| `chatkit.log` | Modeled | `events.onLog` exists; backend diagnostic event coverage should be expanded with golden tests as the protocol evolves. |
| `thread.item.image_generation`, `image_generation.preview.updated` | Supported | Decodes image generation items, applies preview/progress updates, and renders native image previews. |
| `thread.item.generated_image`, `generated_image.updated` | Supported | Decodes generated image items and applies final image/progress updates. |

CSS bundle parity note: the remote CSS references are useful for visual comparison, but ChatKitSwift does not attempt one-to-one CSS variable parity. `index-D9b2ZX6j.css` contains the web component's full design-token system, including variables such as `--chat-background-color`, `--composer-radius`, `--composer-gutter`, `--user-message-background-color`, control/menu/input tokens, and typography scales. `%5Broot-of-the-server%5D__0sigp1o._.css` is primarily app/global CSS, Tailwind output, React Flow `--xy-*` tokens, and Geist font faces. Swift maps the public `theme` options into native SwiftUI equivalents where practical; token-level CSS styling remains web-specific unless explicitly modeled in Swift.

`src_1dg3fzj._.js` is an app-specific Turbopack reference around `useChatKit`, not the core `@openai/chatkit` bundle. It confirms integration behavior for custom `fetch`, `domainKey`, dark/round/compact theme configuration, composer tools/models, entity search, `sendUserMessage`, and `setComposerValue`, but it is treated as integration evidence rather than a separate public API surface.

Runtime-only JS operations observed in the 1.7.0 bundle are intentionally scoped:

- `threads.create_from_shared`, `threads.share`, `threads.stop`, and `threads.init` are ChatGPT-shell/runtime flows, not part of the public `OpenAIChatKit` type surface. ChatKitSwift does not expose them as first-class session methods; custom transports can still send app-specific equivalents.
- `command.shareThread`, `command.setTrainingOptOut`, `chatkit.response.stop`, history open/close, toast, image download, message share, and thread restore events are iframe/shell affordances. Native apps should model those flows in host UI if needed.
- `assistant_message.content_part.inline_widget_added` and `assistant_message.content_part.inline_widget_done` are preserved as unknown item updates. Native inline widget rendering inside Textual assistant markdown is intentionally not implemented yet; top-level `widget` items remain supported.

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

When the backend emits a pending `client_tool_call` item, ChatKitSwift calls `onClientTool` and sends the result back through `threads.add_client_tool_output`. The Swift callback exposes `id` and `callID` in addition to JS-compatible `name` and `params`, and the output request includes `item_id` and `call_id` so your backend can correlate the result with the pending tool call.

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

Widget payloads are assistant response items that describe UI as a tree of
`ChatKitWidgetNode` values. ChatKitSwift decodes each node, keeps unknown fields
in `raw`, and renders the supported components directly in SwiftUI.

The native renderer covers the official ChatKit components used for layout,
content, and interaction: `Basic`, `Box`, `Row`, `Col`, `Card`, `ListView`,
`ListViewItem`, `Title`, `Caption`, `Text`, `Markdown`, `Badge`, `Icon`,
`Image`, `Button`, `Divider`, `Spacer`, `Form`, `Input`, `Textarea`, `Select`,
`DatePicker`, `Checkbox`, `RadioGroup`, `Label`, `Table`, `Table.Row`,
`Table.Cell`, and `Transition`.

OpenAI icon names are mapped to SF Symbols when a native equivalent is known.
`lucide:`-prefixed names use the same mapping after the prefix is removed.
Unmapped values are passed through as SF Symbol names, so package users can also
send symbols such as `doc.text` or `magnifyingglass` directly.

Colors can be semantic tokens such as `primary`, `secondary`, `info`,
`discovery`, `success`, `warning`, and `danger`, or hex values. Widget color
fields can also be light/dark objects, for example `{ "light": "#111827",
"dark": "#F9FAFB" }`, and ChatKitSwift resolves them against the current SwiftUI
color scheme. The renderer also resolves common Widget Studio tokens such as
`surface-tertiary`, `tertiary`, and `green-500` for generated-widget previews.

Forms and controls use native SwiftUI controls. Buttons, list items, card
confirm/cancel actions, form submit actions, and control change actions are sent
to `widgets.onAction` when supplied; otherwise ChatKitSwift sends the custom
action back to the configured backend. Control change actions include the
control `name` and current `value` in the action payload.

Tables render natively from `Table`, `Table.Row`, and `Table.Cell` nodes, with
header rows emphasized and cells laid out as adaptive SwiftUI columns.

The official ChatKit component set does not currently include a dedicated chart
component, but some backends send chart-like custom payloads. ChatKitSwift
includes a simple native bar-chart renderer for `Chart` or `BarChart` nodes with
`data` or `points` arrays containing labels and numeric values.

For local tooling, `ChatKitWidgetPreview` renders a standalone
`ChatKitWidgetNode` without inserting it into a live conversation. If you use
Widget Studio's `convert-widget-to-file` endpoint, `ChatKitWidgetTemplate`
renders the returned `{{ (name) | tojson }}` placeholders with state values and
decodes the result into a native widget node. The iOS demo app includes a Widget
Studio sheet that exercises this flow.

### Widget Screenshot Parity

`WidgetParity/fixtures/widgets.json` contains representative official ChatKit
widget payloads used for native-vs-web screenshot comparison. The fixtures are
fed to both `ChatKitWidgetPreview` and the real ChatKit JS iframe from a local
`chatkit-js` checkout.

Run the full parity workflow from the package root:

```sh
node scripts/widget-parity.js
```

The script renders Swift screenshots with `ChatKitWidgetSnapshot`, starts a
local server for the JS runtime, captures the real iframe with Playwright, crops
both sides to visible widget content, and writes PNG diffs plus
`.widget-parity/report.md`. Generated artifacts, Playwright's local install, and
cached JS chunks stay under `.widget-parity/` and are ignored by git.

Useful variants:

```sh
node scripts/widget-parity.js --allow-failures
node scripts/widget-parity.js --skip-swift
node scripts/widget-parity.js --chatkit-js /Users/ericlewis/Developer/chatkit-js
```

The default asset fallback is `https://cdn.platform.openai.com` for dynamic
`/assets/ck1/*` chunks that are referenced by the saved JS bundle but not present
in `remote_references_to`.

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
try await session.updateThreadTitle("Planning", threadID: "thread_123")
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

await session.setComposerValue(text: "Rewrite this") // preserves the selected tool
await session.setComposerValue(selectedToolID: nil) // clears the selected tool
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

## Attachments, Files, and Dictation

The package models attachments, local file state, attachment request types, and dictation configuration. Host apps still own platform permission flows, file picking, audio capture, upload byte transfer, and backend storage policy.

Attachment request envelopes follow the JS runtime names:

- `attachments.create` uses `name`, `size`, and `mime_type`.
- `attachments.process` uses `attachment_id`, `name`, and optional image `width` / `height`.
- `attachments.get_preview` uses `attachment_id` plus either `conversation_id` or `shared_conversation_id`.
- `attachments.delete` uses `attachment_id`.

Use `AttachmentConfiguration.onRequest` to present the host file picker, upload the bytes through your app/backend, then pass uploaded `ChatKitAttachment` values into the session. The built-in composer can send an attachment-only message once uploaded attachments are present, and protocol requests send their IDs.

`ChatKitLocalFile` values are intentionally local composer state. They are useful while your host app is picking or uploading files, but ChatKitSwift does not upload raw bytes or send local file paths to the backend.

## Development

From the repository root:

```bash
xcrun swift test -Xswiftc -warnings-as-errors
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, project conventions, and the pull request checklist.
