import Foundation
import Synchronization

public final class CYMultiDateDecoder: Sendable {
    public static let shared = CYMultiDateDecoder()

    private struct Formatters {
        let dates: [DateFormatter]
        let iso8601: ISO8601DateFormatter
    }
    private let storage: Mutex<Formatters>

    /// 格式猜测：MM/dd/yyyy 优先于 dd/MM/yyyy；无时区文本使用指定时区。
    public init(timeZone: TimeZone = .current, locale: Locale = Locale(identifier: "en_US_POSIX")) {
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
        let formatters = formats.map { format in
            let f = DateFormatter()
            f.locale = locale
            f.timeZone = timeZone
            f.dateFormat = format
            return f
        }
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.storage = Mutex( Formatters(dates: formatters, iso8601: iso8601))
    }

    public func decode(_ string: String) -> Date? {
        storage.withLock { formatters in
            if let date = formatters.iso8601.date(from: string) { return date }
            for formatter in formatters.dates {
                if let date = formatter.date(from: string) { return date }
            }
            return nil
        }
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

    public static func decode(jsonString: String, decoder: JSONDecoder = JSONDecoder()) throws -> Self {
        try decoder.decode(Self.self, from: Data(jsonString.utf8))
    }

    public static func decode(dictionary: [String: Any], decoder: JSONDecoder = JSONDecoder()) throws -> Self {
        try decoder.decode(Self.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }

    /// 兼容的可选入口；需要错误上下文时使用 decode(jsonString:)。
    public static func from(jsonString: String, decoder: JSONDecoder = JSONDecoder()) -> Self? {
        try? decode(jsonString: jsonString, decoder: decoder)
    }

    public static func from(dictionary: [String: Any], decoder: JSONDecoder = JSONDecoder()) -> Self? {
        try? decode(dictionary: dictionary, decoder: decoder)
    }
}
