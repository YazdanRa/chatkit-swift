# Native Widget Rendering

Render backend-streamed ChatKit widgets as native SwiftUI views.

## Overview

ChatKitSwift decodes widget thread items into ``ChatKitWidgetNode`` trees and renders the known ChatKit component types with SwiftUI controls. Your backend still owns which widgets appear in the conversation. The client receives `widget` items and widget update events, then draws the payload with native layout, text, controls, actions, colors, and icons.

Use ``ChatKitOptions/Widgets`` when the host app wants to intercept widget actions. If no action callback is installed, ChatKitSwift sends the action back to the current thread with ``ChatKitSession/sendCustomAction(_:itemID:)``.

```swift
let options = ChatKitOptions(
    api: .custom(url: chatEndpoint),
    theme: .init(
        colorScheme: .system,
        color: .init(
            surface: .init(background: "#FFFFFF", foreground: "#111827")
        )
    ),
    widgets: .init { action, item in
        print("Widget action", action.type, "from", item.id)
    }
)
```

## Supported Components

The native renderer understands the official ChatKit widget building blocks:

- Layout: `Basic`, `Box`, `Card`, `Row`, `Col`, `ListView`, `ListViewItem`, `Divider`, `Spacer`, and `Transition`.
- Text and media: `Title`, `Caption`, `Text`, `Markdown`, `Badge`, `Icon`, and `Image`.
- Actions: `Button`, card `confirm` and `cancel` actions, `onClickAction`, `onSubmitAction`, and `onChangeAction`.
- Forms: `Form`, `Input`, `Textarea`, `Select`, `DatePicker`, `Checkbox`, and `RadioGroup`.
- Tables: `Table`, `Table.Row`, and `Table.Cell`.

Unknown component types are preserved and shown with their children, so newer backend payloads remain forward-compatible while the renderer catches up.

The official ChatKit component set does not currently include a dedicated chart component. ChatKitSwift still recognizes `Chart` and `BarChart` custom payloads and renders simple labeled bar rows from `data` or `points` arrays for backends that already send chart-like widgets.

## Actions and Forms

Action nodes carry a `type` and optional `payload`. Buttons and list items trigger click actions. Forms render a Submit button when `onSubmitAction` is present. Form controls add the control `name` and current `value` to `onChangeAction` payloads before dispatch.

The default action path streams `threads.custom_action` through the configured transport. Install `onAction` on ``ChatKitOptions/Widgets`` only when the app needs to intercept an action locally, add host app context, route to a native screen, or call its own API.

## Icons, Colors, and Theme

Widget icons render with SF Symbols. Payloads can send SF Symbol names directly, or common ChatKit and Lucide-style names such as `lucide:badge-check`, `chart`, `external-link`, `sparkle`, and `settings-cog`; ChatKitSwift maps those names to platform symbols.

Widget colors accept semantic tones such as `primary`, `secondary`, `info`, `success`, `warning`, and `danger`, or CSS-style hex strings such as `"#2563EB"`. Color fields can also provide light and dark values:

```json
{ "background": { "light": "#FFFFFF", "dark": "#111827" } }
```

Common generated-widget tokens such as `surface-tertiary`, `tertiary`, `green-500`, `red-500`, and `blue-500` resolve to native SwiftUI colors.

The surrounding chat surface still uses ``ChatKitTheme`` for its preferred color scheme, background, foreground, radius, density, and typography settings.

## Generated Widget Tooling

Use ``ChatKitWidgetPreview`` to render a standalone ``ChatKitWidgetNode`` in a demo, fixture, or local test harness. It reuses the same native renderer as transcript widget items without requiring a live conversation.

Use ``ChatKitWidgetTemplate`` with Widget Studio-style template JSON. It replaces `{{ (name) | tojson }}` placeholders with supplied state values and decodes the rendered JSON into a ``ChatKitWidgetNode``.

## Example Payload

A backend can stream a widget item like this:

```json
{
  "type": "thread.item.done",
  "item": {
    "type": "widget",
    "id": "widget_project_status",
    "thread_id": "thread_123",
    "created_at": "2026-05-25T14:00:00Z",
    "widget": {
      "type": "Card",
      "size": "lg",
      "children": [
        { "type": "Title", "value": "Project status" },
        { "type": "Badge", "label": "On track", "color": "success" },
        {
          "type": "BarChart",
          "data": [
            { "label": "Design", "value": 8, "color": "#2563EB" },
            { "label": "Build", "value": 5, "color": "#16A34A" },
            { "label": "QA", "value": 3, "color": "#F59E0B" }
          ]
        },
        {
          "type": "Form",
          "children": [
            {
              "type": "Select",
              "name": "priority",
              "placeholder": "Priority",
              "options": [
                { "label": "Normal", "value": "normal" },
                { "label": "Urgent", "value": "urgent" }
              ],
              "onChangeAction": {
                "type": "project.priority.changed",
                "payload": { "project_id": "proj_123" }
              }
            }
          ],
          "onSubmitAction": {
            "type": "project.status.submitted",
            "payload": { "project_id": "proj_123" }
          }
        }
      ]
    }
  }
}
```

Widget updates can replace the root widget, replace a component by ID, or append streaming text through `widget.root.updated`, `widget.component.updated`, and `widget.streaming_text.value_delta` events.
