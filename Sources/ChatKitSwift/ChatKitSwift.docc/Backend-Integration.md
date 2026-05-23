# Backend Integration

Connect ChatKitSwift to a backend that owns auth, OpenAI credentials, persistence, and streaming.

## Keep Provider Credentials Server-Side

Do not put OpenAI API keys in an iOS, macOS, or visionOS app. A production app should authenticate the user, call your backend, and let the backend call OpenAI or another provider server-side.

Use a custom endpoint when your backend implements the ChatKit protocol directly:

```swift
let options = ChatKitOptions(
    api: .custom(
        url: URL(string: "https://yourapp.example.com/api/chatkit")!,
        additionalHeaders: {
            let token = try await AuthTokenProvider.shared.token()
            return ["Authorization": "Bearer \(token)"]
        }
    )
)
```

Use a hosted configuration only when your backend can mint and refresh short-lived ChatKit client secrets:

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

## Request Shape

The built-in transport posts ``ChatKitRequest`` envelopes to the configured endpoint. A user message request includes input content, attachments, and inference options:

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

Non-streaming requests should return JSON for the requested resource. Streaming requests should return `text/event-stream`, with each event payload encoded as a ``ChatKitEvent``:

```text
data: {"type":"thread.created","thread":{"id":"thread_123","title":"New chat","created_at":"2026-05-23T00:00:00Z","status":{"type":"active"},"items":{"data":[],"has_more":false}}}

data: {"type":"thread.item.done","item":{"type":"assistant_message","id":"msg_123","thread_id":"thread_123","created_at":"2026-05-23T00:00:01Z","content":[{"type":"output_text","text":"Hello","annotations":[]}]}}
```

## Custom Transport

Inject a custom ``ChatKitTransport`` for previews, tests, local fixtures, or a backend that does not use the default single-endpoint shape.

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
