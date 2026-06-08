import ChatKitSwift
import SwiftUI

struct WidgetStudioSheet: View {
    @Environment(\.dismiss) private var dismiss

    let theme: ChatKitTheme
    private let client = WidgetStudioClient()

    @State private var prompt = "a compact project status widget"
    @State private var generatedWidget: WidgetStudioGeneratedWidget?
    @State private var errorMessage: String?
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                promptSection
                statusSection
                if let generatedWidget {
                    previewSection(generatedWidget)
                    sourceSection(generatedWidget)
                }
            }
            .navigationTitle("Widget Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var promptSection: some View {
        Section {
            TextField("Prompt", text: $prompt, axis: .vertical)
                .lineLimit(3 ... 6)

            Button("Generate", systemImage: "wand.and.sparkles") {
                Task { await generate() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Label("Prompt", systemImage: "text.cursor")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if isGenerating || errorMessage != nil {
            Section {
                if isGenerating {
                    HStack {
                        ProgressView()
                        Text("Generating")
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func previewSection(_ generatedWidget: WidgetStudioGeneratedWidget) -> some View {
        Section {
            ChatKitWidgetPreview(
                widget: generatedWidget.widget,
                theme: theme,
                onAction: { action, item in
                    print("Generated widget action \(action.type) from \(item.id)")
                },
            )
            .padding(.vertical, 8)
        } header: {
            Label(generatedWidget.name, systemImage: "rectangle.3.group")
        } footer: {
            Text(generatedWidget.prompt)
        }
    }

    private func sourceSection(_ generatedWidget: WidgetStudioGeneratedWidget) -> some View {
        Section {
            DisclosureGroup("JSX") {
                WidgetStudioCodeBlock(text: generatedWidget.widgetJSX)
            }

            DisclosureGroup("Schema") {
                WidgetStudioCodeBlock(text: generatedWidget.schema)
            }

            DisclosureGroup("State") {
                WidgetStudioCodeBlock(text: generatedWidget.prettyStateJSON)
            }

            DisclosureGroup("Template JSON") {
                WidgetStudioCodeBlock(text: generatedWidget.templateJSON)
            }

            DisclosureGroup("Rendered JSON") {
                WidgetStudioCodeBlock(text: generatedWidget.renderedJSON)
            }
        } header: {
            Label("Generated Source", systemImage: "chevron.left.forwardslash.chevron.right")
        }
    }

    @MainActor
    private func generate() async {
        guard !isGenerating else {
            return
        }

        isGenerating = true
        errorMessage = nil

        do {
            generatedWidget = try await client.generateWidget(prompt: prompt)
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}

private struct WidgetStudioCodeBlock: View {
    var text: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }
}
