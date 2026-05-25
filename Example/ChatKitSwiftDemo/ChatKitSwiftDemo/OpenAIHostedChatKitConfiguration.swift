import ChatKitSwift
import Foundation

struct OpenAIHostedChatKitConfiguration {
    private let environment = DemoEnvironment()

    func options() -> Result<ChatKitOptions, Error> {
        do {
            let apiKey = try environment.requiredValue(named: "OPENAI_API_KEY")
            let workflowID = try environment.requiredValue(named: "OPENAI_CHATKIT_WORKFLOW_ID")
            let userID = environment.value(named: "OPENAI_CHATKIT_USER_ID") ?? "chatkitswift-demo-user"
            let clientSecretProvider = OpenAIHostedClientSecretProvider(
                apiKey: apiKey,
                workflowID: workflowID,
                userID: userID,
            )

            return .success(
                ChatKitOptions(
                    api: .hosted { currentClientSecret in
                        try await clientSecretProvider.clientSecret(currentClientSecret: currentClientSecret)
                    },
                    frameTitle: "ChatKitSwiftDemo",
                    startScreen: .init(
                        greeting: "What can I help with today?",
                        prompts: [
                            .init(
                                label: "Test the assistant",
                                prompt: .text("Say hello and briefly describe what you can do."),
                            ),
                        ],
                    ),
                    threadItemActions: .init(feedback: true, retry: true),
                    composer: .init(placeholder: "Message the assistant"),
                    thread: .init(autoScroll: true),
                    events: .init(
                        onError: { error in
                            print(error.message ?? error.code)
                        },
                    ),
                ),
            )
        } catch {
            return .failure(error)
        }
    }
}

private actor OpenAIHostedClientSecretProvider {
    private let apiKey: String
    private let workflowID: String
    private let userID: String
    private var cachedSession: CreateChatKitSessionResponse?

    init(apiKey: String, workflowID: String, userID: String) {
        self.apiKey = apiKey
        self.workflowID = workflowID
        self.userID = userID
    }

    func clientSecret(currentClientSecret: String?) async throws -> String {
        if let cachedSession,
           cachedSession.clientSecret == currentClientSecret,
           cachedSession.expiresAt > Date().addingTimeInterval(60)
        {
            return cachedSession.clientSecret
        }

        let session = try await createClientSecret()
        cachedSession = session
        return session.clientSecret
    }

    private func createClientSecret() async throws -> CreateChatKitSessionResponse {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chatkit/sessions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("chatkit_beta=v1", forHTTPHeaderField: "OpenAI-Beta")

        request.httpBody = try JSONEncoder().encode(
            CreateChatKitSessionRequest(
                workflow: .init(id: workflowID),
                user: userID,
            ),
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DemoConfigurationError.invalidSessionResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw DemoConfigurationError.sessionRequestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(CreateChatKitSessionResponse.self, from: data)
    }
}

private struct CreateChatKitSessionRequest: Encodable {
    var workflow: Workflow
    var user: String

    struct Workflow: Encodable {
        var id: String
    }
}

private struct CreateChatKitSessionResponse: Decodable {
    var clientSecret: String
    var expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case expiresAt = "expires_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientSecret = try container.decode(String.self, forKey: .clientSecret)
        let expiresAtTimestamp = try container.decode(TimeInterval.self, forKey: .expiresAt)
        expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)
    }
}

enum DemoConfigurationError: LocalizedError {
    case missingValue(String)
    case invalidSessionResponse
    case sessionRequestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(name):
            "Missing \(name). Add it to Example/ChatKitSwiftDemo/.env or provide it as a process environment variable."
        case .invalidSessionResponse:
            "OpenAI returned a non-HTTP session response."
        case let .sessionRequestFailed(statusCode, message):
            "OpenAI ChatKit session request failed with HTTP \(statusCode): \(message)"
        }
    }
}
