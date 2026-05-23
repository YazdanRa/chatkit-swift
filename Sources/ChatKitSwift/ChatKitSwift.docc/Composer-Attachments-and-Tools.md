# Composer, Attachments, and Tools

Configure the composer controls while keeping platform-specific work in the host app.

## Composer Options

``ChatKitOptions/Composer`` controls the placeholder, attachment affordance, tool selection, model selection, and dictation state.

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    composer: .init(
        placeholder: "Ask support",
        attachments: .init(
            enabled: true,
            maxCount: 5,
            onRequest: {
                // Present your app's file picker.
            }
        ),
        tools: [
            .init(id: "tickets", label: "Tickets", icon: "tray.full", pinned: true)
        ],
        models: [
            .init(id: "fast", label: "Fast", isDefault: true)
        ],
        dictation: .init(enabled: true)
    )
)
```

## Attachments

ChatKitSwift models attachment configuration, local file state, and attachment references, but the host app owns platform permission flows, file picking, upload byte transfer, and backend storage policy.

Use the `onRequest` callback to present native file or photo picking UI from the host app. After the host app creates or receives a ``ChatKitAttachment`` value, update the composer through ``ChatKitSession/setComposerValue(text:content:reply:attachments:files:selectedToolID:selectedModelID:)``.

```swift
@MainActor
func attachUploadedFile(to session: ChatKitSession, fileID: String) async {
    await session.setComposerValue(
        attachments: [
            .file(
                .init(
                    id: fileID,
                    name: "Project brief.pdf",
                    mimeType: "application/pdf"
                )
            )
        ]
    )
}
```

## Tools, Models, and Mentions

Tools and models are composer metadata. The selected values are sent with user input as inference options so the backend can decide which model or tool policy to apply.

Entities power rich mentions and previews:

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
        }
    )
)
```

The package keeps these controls native to SwiftUI while preserving protocol fields it does not understand yet, so newer backend payloads can remain forward-compatible.
