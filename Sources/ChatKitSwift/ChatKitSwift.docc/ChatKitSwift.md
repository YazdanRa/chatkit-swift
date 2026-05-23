# ``ChatKitSwift``

Embed a native SwiftUI chat surface that speaks the OpenAI ChatKit protocol.

## Overview

ChatKitSwift packages the SwiftUI views, session controller, transport, and Codable protocol models needed to add a ChatKit conversation to an iOS, macOS, or visionOS app. The package keeps OpenAI API keys out of client apps: your app talks to a backend endpoint, and that backend owns user authorization, OpenAI calls, storage, and streamed ChatKit events.

Use ``ChatKitView`` when the chat surface can own its own ``ChatKitSession``. Create and inject a ``ChatKitSession`` when the host app needs to load threads, send messages, or update composer state from surrounding UI.

```swift
import ChatKitSwift
import Foundation
import SwiftUI

struct AssistantScreen: View {
    var body: some View {
        ChatKitView(
            options: ChatKitOptions(
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
                )
            )
        )
    }
}
```

### Production Boundary

ChatKitSwift is a client package. Production apps should pass user-scoped auth headers or short-lived client secrets to ChatKitSwift, then keep OpenAI API keys and provider credentials server-side. The built-in HTTP transport sends ChatKit request envelopes to the configured endpoint and consumes JSON or server-sent ChatKit events in response.

## Topics

### Start Here

- <doc:Getting-Started>
- <doc:Backend-Integration>
- <doc:Composer-Attachments-and-Tools>

### Core Types

- ``ChatKitView``
- ``ChatKitSession``
- ``ChatKitOptions``
- ``ChatKitTransport``

### Protocol Models

- ``ChatKitRequest``
- ``ChatKitEvent``
- ``ChatKitThread``
- ``ChatKitThreadItem``
- ``ChatKitWidgetNode``
