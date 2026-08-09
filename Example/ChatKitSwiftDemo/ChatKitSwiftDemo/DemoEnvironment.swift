import Foundation

struct DemoEnvironment {
    private let processEnvironment: [String: String]
    private let fileEnvironment: [String: String]

    init(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main,
    ) {
        self.processEnvironment = processEnvironment
        fileEnvironment = Self.loadDotEnv(from: bundle)
    }

    func value(named name: String) -> String? {
        if let value = processEnvironment[name]?.nilIfBlank {
            return value
        }

        return fileEnvironment[name]?.nilIfBlank
    }

    func requiredValue(named name: String) throws -> String {
        guard let value = value(named: name) else {
            throw DemoConfigurationError.missingValue(name)
        }

        return value
    }

    func requiredURL(named name: String) throws -> URL {
        let rawValue = try requiredValue(named: name)
        guard let url = URL(string: rawValue),
              url.scheme != nil,
              url.host != nil
        else {
            throw DemoConfigurationError.invalidURL(name)
        }

        return url
    }

    private static func loadDotEnv(from bundle: Bundle) -> [String: String] {
        guard let url = bundle.resourceURL?.appendingPathComponent(".env"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return [:]
        }

        return Dictionary(
            uniqueKeysWithValues: contents
                .split(whereSeparator: \.isNewline)
                .compactMap(parseLine),
        )
    }

    private static func parseLine(_ line: Substring) -> (String, String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty,
              !trimmedLine.hasPrefix("#"),
              let separator = trimmedLine.firstIndex(of: "=")
        else {
            return nil
        }

        let key = trimmedLine[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = trimmedLine[trimmedLine.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            return nil
        }

        return (key, rawValue.trimmingMatchingQuotes)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmingMatchingQuotes: String {
        guard count >= 2,
              let first,
              let last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'")
        else {
            return self
        }

        return String(dropFirst().dropLast())
    }
}
