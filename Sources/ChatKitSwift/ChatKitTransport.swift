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
