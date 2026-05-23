import Foundation

public enum ChatKitJSON {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601Formatter(includeFractionalSeconds: true).string(from: date))
        }
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = decodeDate(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }

    private static func decodeDate(from value: String) -> Date? {
        let normalizedValue = normalizedISO8601DateString(value)
        return iso8601Formatter(includeFractionalSeconds: true).date(from: normalizedValue)
            ?? iso8601Formatter(includeFractionalSeconds: false).date(from: normalizedValue)
    }

    private static func normalizedISO8601DateString(_ value: String) -> String {
        hasTimezoneDesignator(value) ? value : "\(value)Z"
    }

    private static func hasTimezoneDesignator(_ value: String) -> Bool {
        guard let separatorIndex = value.firstIndex(of: "T") else {
            return false
        }

        let time = value[value.index(after: separatorIndex)...]
        return time.contains("Z") || time.contains("+") || time.dropFirst().contains("-")
    }

    private static func iso8601Formatter(includeFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includeFractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }
}
