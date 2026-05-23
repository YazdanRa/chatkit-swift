import Foundation

public protocol ChatKitTransport: Sendable {
    func send(_ request: ChatKitRequest) async throws -> Data
    func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error>
}

public enum ChatKitTransportError: Error, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int, Data)
    case missingCurrentThread
    case invalidPayload(String)
}

extension ChatKitTransportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from ChatKit server"
        case let .httpStatus(statusCode, data):
            if let message = Self.message(from: data) {
                "HTTP \(statusCode): \(message)"
            } else {
                "HTTP \(statusCode)"
            }
        case .missingCurrentThread:
            "No active ChatKit thread"
        case let .invalidPayload(payload):
            "Invalid ChatKit payload: \(payload)"
        }
    }

    private static func message(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = firstString(in: object, keys: ["detail", "message", "error"]) {
                return message
            }
            if let error = object["error"] as? [String: Any],
               let message = firstString(in: error, keys: ["detail", "message", "error"]) {
                return message
            }
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
