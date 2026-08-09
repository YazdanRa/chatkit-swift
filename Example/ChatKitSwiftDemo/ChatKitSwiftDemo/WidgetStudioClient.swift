import ChatKitSwift
import Foundation

actor WidgetStudioClient {
    private let baseURL = URL(string: "https://widgets.chatkit.studio")!
    private let editorReferer = "https://widgets.chatkit.studio/editor/097539e6-6d66-4cc8-b8d7-824e1e8b0dc8"
    private let userID: String

    init(userID: String = WidgetStudioUserID.current()) {
        self.userID = userID
    }

    func generateWidget(prompt: String) async throws -> WidgetStudioGeneratedWidget {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw WidgetStudioClientError.emptyPrompt
        }

        let created = try await createWidget(prompt: trimmedPrompt)
        let converted = try await convertWidgetToFile(widgetJSX: created.view)
        let template = ChatKitWidgetTemplate(template: converted.template, state: created.state)

        return try WidgetStudioGeneratedWidget(
            name: created.name,
            prompt: trimmedPrompt,
            widgetJSX: created.view,
            schema: created.schema,
            state: created.state,
            templateJSON: converted.template,
            renderedJSON: template.renderJSON(),
            widget: template.renderNode(),
        )
    }

    private func createWidget(prompt: String) async throws -> WidgetStudioCreateResponse {
        try await post(
            path: "/create-widget",
            body: WidgetStudioCreateRequest(userId: userID, prompt: prompt, attachments: []),
        )
    }

    private func convertWidgetToFile(widgetJSX: String) async throws -> WidgetStudioConvertResponse {
        try await post(
            path: "/convert-widget-to-file",
            body: WidgetStudioConvertRequest(widgetJsx: widgetJSX),
        )
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request,
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(editorReferer, forHTTPHeaderField: "Referer")
        request.setValue("ChatKitSwiftDemo/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WidgetStudioClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw WidgetStudioClientError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

struct WidgetStudioGeneratedWidget: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var prompt: String
    var widgetJSX: String
    var schema: String
    var state: [String: JSONValue]
    var templateJSON: String
    var renderedJSON: String
    var widget: ChatKitWidgetNode

    var prettyStateJSON: String {
        (try? Self.prettyJSONString(from: state)) ?? "{}"
    }

    private static func prettyJSONString(from value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

enum WidgetStudioClientError: LocalizedError {
    case emptyPrompt
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            "Enter a prompt before generating a widget."
        case .invalidResponse:
            "Widget Studio returned a non-HTTP response."
        case let .requestFailed(statusCode, message):
            "Widget Studio request failed with HTTP \(statusCode): \(message)"
        }
    }
}

private struct WidgetStudioCreateRequest: Encodable {
    var userId: String
    var prompt: String
    var attachments: [String]
}

private struct WidgetStudioConvertRequest: Encodable {
    var widgetJsx: String
}

private struct WidgetStudioCreateResponse: Decodable {
    var name: String
    var view: String
    var schema: String
    var state: [String: JSONValue]
}

private struct WidgetStudioConvertResponse: Decodable {
    var template: String
}

private enum WidgetStudioUserID {
    private static let key = "ChatKitSwiftDemo.WidgetStudioUserID"

    static func current(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: key) {
            return existing
        }

        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }
}
