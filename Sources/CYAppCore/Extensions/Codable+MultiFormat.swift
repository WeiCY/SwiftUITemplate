import Foundation

public final class CYMultiDateDecoder: @unchecked Sendable {
    public static let shared = CYMultiDateDecoder()

    private let formatters: [DateFormatter]
    private let iso8601: ISO8601DateFormatter

    private init() {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy"
        ]
        self.formatters = formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
        self.iso8601 = ISO8601DateFormatter()
        self.iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func decode(_ string: String) -> Date? {
        if let date = iso8601.date(from: string) { return date }
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

extension JSONDecoder.DateDecodingStrategy {
    public static var cyMultiFormat: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            let string = try container.decode(String.self)
            if let date = CYMultiDateDecoder.shared.decode(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
    }
}

extension Encodable {

    public func toDictionary(encoder: JSONEncoder = JSONEncoder()) -> [String: Any]? {
        guard let data = try? encoder.encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

extension Decodable {

    public static func from(jsonString: String, decoder: JSONDecoder = JSONDecoder()) -> Self? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? decoder.decode(Self.self, from: data)
    }

    public static func from(dictionary: [String: Any], decoder: JSONDecoder = JSONDecoder()) -> Self? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
        return try? decoder.decode(Self.self, from: data)
    }
}
