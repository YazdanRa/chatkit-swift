# Getting Started

Install ChatKitSwift, configure a backend endpoint, and embed the SwiftUI chat surface.

## Requirements

ChatKitSwift requires Swift 6.3 or newer and supports iOS 17, macOS 14, and visionOS 1. The repository root is the Swift package root.

## Add the Package

Add the package in Xcode with **File > Add Package Dependencies**, or add it to a Swift Package manifest:

```swift
.dependencies([
    .package(url: "https://github.com/YazdanRa/chatkit-swift.git", from: "0.1.0")
])
```

Then add the library product to the target that owns your chat UI:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ChatKitSwift", package: "chatkit-swift")
    ]
)
```

## Embed the Chat View

Create ``ChatKitOptions`` with a backend URL and pass it to ``ChatKitView``.

```swift
import ChatKitSwift
import Foundation
import SwiftUI

struct ChatScreen: View {
    var body: some View {
        ChatKitView(
            options: ChatKitOptions(
                api: .custom(
                    url: URL(string: "https://yourapp.example.com/api/chatkit")!
                ),
                frameTitle: "Support"
            )
        )
    }
}
```

## Drive the Session From Host UI

If the app needs to control the thread from outside the chat surface, create a ``ChatKitSession`` and inject it.

```swift
import ChatKitSwift
import Foundation
import SwiftUI

@MainActor
struct ControlledChatScreen: View {
    @State private var session: ChatKitSession

    init() {
        let options = ChatKitOptions(
            api: .custom(
                url: URL(string: "https://yourapp.example.com/api/chatkit")!
            )
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

Use session methods such as ``ChatKitSession/loadThreads(limit:order:after:)``, ``ChatKitSession/setThreadId(_:)``, ``ChatKitSession/sendUserMessage(text:content:reply:attachments:newThread:toolChoice:model:)``, and ``ChatKitSession/setComposerValue(text:content:reply:attachments:files:selectedToolID:selectedModelID:)`` when surrounding UI needs to coordinate with the conversation.
