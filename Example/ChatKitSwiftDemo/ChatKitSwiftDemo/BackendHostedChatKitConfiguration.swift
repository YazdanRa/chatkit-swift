import ChatKitSwift
import Foundation

struct BackendHostedChatKitConfiguration {
    private let environment = DemoEnvironment()

    func options() -> Result<ChatKitOptions, Error> {
        do {
            let sessionEndpoint = try environment.requiredURL(named: "OPENAI_CHATKIT_SESSION_ENDPOINT")
            let clientSecretProvider = BackendHostedClientSecretProvider(sessionEndpoint: sessionEndpoint)

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

private actor BackendHostedClientSecretProvider {
    private let sessionEndpoint: URL
    private var cachedSession: BackendChatKitSessionResponse?

    init(sessionEndpoint: URL) {
        self.sessionEndpoint = sessionEndpoint
    }

    func clientSecret(currentClientSecret: String?) async throws -> String {
        if let cachedSession,
           cachedSession.clientSecret == currentClientSecret,
           cachedSession.expiresAt.map({ $0 > Date().addingTimeInterval(60) }) == true
        {
            return cachedSession.clientSecret
        }

        let session = try await createClientSecret()
        cachedSession = session
        return session.clientSecret
    }

    private func createClientSecret() async throws -> BackendChatKitSessionResponse {
        var request = URLRequest(url: sessionEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let cachedSession {
            request.setValue(cachedSession.clientSecret, forHTTPHeaderField: "X-Current-Client-Secret")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DemoConfigurationError.invalidSessionResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw DemoConfigurationError.sessionRequestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(BackendChatKitSessionResponse.self, from: data)
    }
}

private struct BackendChatKitSessionResponse: Decodable {
    var clientSecret: String
    var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case clientSecretCamel = "clientSecret"
        case clientSecret = "client_secret"
        case expiresAtCamel = "expiresAt"
        case expiresAt = "expires_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientSecret = try container.decodeIfPresent(String.self, forKey: .clientSecret)
            ?? container.decode(String.self, forKey: .clientSecretCamel)
        expiresAt = Self.decodeDate(from: container, snakeKey: .expiresAt, camelKey: .expiresAtCamel)
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        snakeKey: CodingKeys,
        camelKey: CodingKeys,
    ) -> Date? {
        if let timestamp = try? container.decodeIfPresent(TimeInterval.self, forKey: snakeKey) {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = try? container.decodeIfPresent(TimeInterval.self, forKey: camelKey) {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let iso8601 = try? container.decodeIfPresent(String.self, forKey: snakeKey) {
            return ISO8601DateFormatter().date(from: iso8601)
        }
        if let iso8601 = try? container.decodeIfPresent(String.self, forKey: camelKey) {
            return ISO8601DateFormatter().date(from: iso8601)
        }
        return nil
    }
}

enum DemoConfigurationError: LocalizedError {
    case missingValue(String)
    case invalidURL(String)
    case invalidSessionResponse
    case sessionRequestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(name):
            "Missing \(name). Set it in the Xcode scheme or process environment."
        case let .invalidURL(name):
            "\(name) must be an absolute URL for your backend ChatKit session endpoint."
        case .invalidSessionResponse:
            "The ChatKit session endpoint returned a non-HTTP response."
        case let .sessionRequestFailed(statusCode, message):
            "ChatKit session request failed with HTTP \(statusCode): \(message)"
        }
    }
}
