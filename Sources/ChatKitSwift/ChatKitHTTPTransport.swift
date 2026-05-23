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

                    var dataLines: [String] = []
                    for try await line in bytes.lines {
                        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if !dataLines.isEmpty {
                                try yieldEvent(from: dataLines.joined(separator: "\n"), to: continuation)
                                dataLines.removeAll(keepingCapacity: true)
                            }
                            continue
                        }

                        guard line.hasPrefix("data:") else {
                            continue
                        }

                        var value = String(line.dropFirst("data:".count))
                        if value.first == " " {
                            value.removeFirst()
                        }
                        dataLines.append(value)
                    }

                    if !dataLines.isEmpty {
                        try yieldEvent(from: dataLines.joined(separator: "\n"), to: continuation)
                    }
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

    private func yieldEvent(from payload: String, to continuation: AsyncThrowingStream<ChatKitEvent, Error>.Continuation) throws {
        guard let data = payload.data(using: .utf8) else {
            throw ChatKitTransportError.invalidPayload(payload)
        }
        continuation.yield(try ChatKitJSON.decoder.decode(ChatKitEvent.self, from: data))
    }
}

private actor ChatKitHostedSecretStore {
    private(set) var currentSecret: String?

    func set(_ secret: String) {
        currentSecret = secret
    }
}
