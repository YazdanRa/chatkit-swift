import SwiftUI
import Textual

struct ChatKitAssistantResponseTextView: View {
    let markdown: String

    var body: some View {
        StructuredText(markdown: markdown)
            .font(.body)
            .textual.textSelection(.enabled)
    }
}
