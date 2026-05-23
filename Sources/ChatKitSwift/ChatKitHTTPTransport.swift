import Foundation

public struct ChatKitHTTPTransport: ChatKitTransport {
    private let api: ChatKitAPI
    private let urlSession: URLSession
    private let betaHeader: String
    private let hostedSecretStore = ChatKitHostedSecretStore()

    public init(api: ChatKitAPI, urlSession: URLSession = .shared, betaHeader: String = "chatkit_beta=v1") {
        self.api = api
        self.urlSession = urlSession
        self.betaHeader = betaHeader
    }

    public func send(_ request: ChatKitRequest) async throws -> Data {
        let urlRequest = try await makeURLRequest(for: request, acceptsStream: false)
        let (data, response) = try await urlSession.data(for: urlRequest)
        try validate(response: response, data: data)
        return data
    }

    public func stream(_ request: ChatKitRequest) async throws -> AsyncThrowingStream<ChatKitEvent, Error> {
        let urlRequest = try await makeURLRequest(for: request, acceptsStream: true)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)
                    try validate(response: response, data: Data())

                    var parser = ChatKitSSEParser()
                    var lineBytes: [UInt8] = []
                    for try await byte in bytes {
                        lineBytes.append(byte)
                        guard byte == Self.lineFeedByte else {
                            continue
                        }

                        try yieldEvents(from: String(decoding: lineBytes, as: UTF8.self), parser: &parser, to: continuation)
                        lineBytes.removeAll(keepingCapacity: true)
                    }

                    if !lineBytes.isEmpty {
                        try yieldEvents(from: String(decoding: lineBytes, as: UTF8.self), parser: &parser, to: continuation)
                    }
                    try yieldEvents(parser.finish(), to: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeURLRequest(for request: ChatKitRequest, acceptsStream: Bool) async throws -> URLRequest {
        let body = try ChatKitJSON.encoder.encode(request)
        var urlRequest = URLRequest(url: try await endpointURL())
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(acceptsStream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")

        switch api {
        case let .custom(config):
            if let domainKey = config.domainKey {
                urlRequest.setValue(domainKey, forHTTPHeaderField: "OpenAI-Domain-Key")
            }
            for (key, value) in try await config.additionalHeaders() {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        case let .hosted(config):
            let currentSecret = await hostedSecretStore.currentSecret
            let clientSecret = try await config.getClientSecret(currentSecret)
            await hostedSecretStore.set(clientSecret)
            urlRequest.setValue("Bearer \(clientSecret)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(betaHeader, forHTTPHeaderField: "OpenAI-Beta")
        }

        return urlRequest
    }

    private func endpointURL() async throws -> URL {
        switch api {
        case let .custom(config):
            config.url
        case let .hosted(config):
            config.endpoint
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ChatKitTransportError.invalidResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            throw ChatKitTransportError.httpStatus(response.statusCode, data)
        }
    }

    private func yieldEvents(
        from chunk: String,
        parser: inout ChatKitSSEParser,
        to continuation: AsyncThrowingStream<ChatKitEvent, Error>.Continuation
    ) throws {
        try yieldEvents(parser.append(chunk), to: continuation)
    }

    private func yieldEvents(
        _ payloads: [String],
        to continuation: AsyncThrowingStream<ChatKitEvent, Error>.Continuation
    ) throws {
        for payload in payloads {
            try yieldEvent(from: payload, to: continuation)
        }
    }

    private func yieldEvent(from payload: String, to continuation: AsyncThrowingStream<ChatKitEvent, Error>.Continuation) throws {
        guard let data = payload.data(using: .utf8) else {
            throw ChatKitTransportError.invalidPayload(payload)
        }
        do {
            continuation.yield(try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data))
        } catch {
            throw ChatKitTransportError.eventDecodingFailed(payload: payload, reason: error.localizedDescription)
        }
    }

    private static let lineFeedByte = UInt8(ascii: "\n")
}

private actor ChatKitHostedSecretStore {
    private(set) var currentSecret: String?

    func set(_ secret: String) {
        currentSecret = secret
    }
}
