import Foundation

public struct ChatKitSSEParser: Sendable {
    private var buffer = ""

    public init() {}

    public mutating func append(_ chunk: String) -> [String] {
        buffer += chunk

        var payloads: [String] = []
        while let range = buffer.range(of: #"\r?\n[ \t\r]*\r?\n"#, options: .regularExpression) {
            let frame = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            appendPayload(from: frame, to: &payloads)
        }

        return payloads
    }

    public mutating func finish() -> [String] {
        var payloads: [String] = []
        if buffer.contains("data:") {
            appendPayload(from: buffer, to: &payloads)
            buffer.removeAll(keepingCapacity: true)
        }
        return payloads
    }

    private func appendPayload(from frame: String, to payloads: inout [String]) {
        let dataLines = frame
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                var line = String(line)
                if line.last == "\r" {
                    line.removeLast()
                }

                guard line.hasPrefix("data:") else {
                    return nil
                }

                var value = String(line.dropFirst("data:".count))
                if value.first == " " {
                    value.removeFirst()
                }
                return value
            }

        if !dataLines.isEmpty {
            payloads.append(dataLines.joined(separator: "\n"))
        }
    }
}
