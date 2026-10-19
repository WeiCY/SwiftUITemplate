import Foundation

/// 所有网络日志共享的保守脱敏规则。仅对已知字段名脱敏；不要把秘密放入普通字段或 URL 路径。
public enum CYNetworkLogRedactor {
    private static let sensitiveNames: Set<String> = [
        "password", "passwd", "token", "accesstoken", "refreshtoken", "idtoken",
        "secret", "clientsecret", "apikey", "authorization", "proxyauthorization",
        "cookie", "setcookie", "xapikey", "xauthtoken", "credential", "signature"
    ]

    public static func isSensitive(_ name: String) -> Bool {
        sensitiveNames.contains(name.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// 支持完整 URL 和相对端点；移除 user/password/fragment，无法解析时隐藏全文。
    public static func url(_ value: String) -> String {
        guard var components = URLComponents(string: value) else { return "[URL omitted]" }
        components.user = nil
        components.password = nil
        components.fragment = nil
        components.queryItems = components.queryItems?.map {
            URLQueryItem(name: $0.name, value: isSensitive($0.name) ? "***" : $0.value)
        }
        return components.string ?? "[URL omitted]"
    }

    public static func body(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              object is [String: Any] || object is [Any],
              let redacted = try? JSONSerialization.data(withJSONObject: redact(object), options: [.sortedKeys]),
              let text = String(data: redacted, encoding: .utf8) else {
            return "[non-JSON body omitted: \(data.count) bytes]"
        }
        return text
    }

    private static func redact(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            return dictionary.mapValues { redact($0) }.merging(
                dictionary.filter { isSensitive($0.key) }.mapValues { _ in "***" as Any },
                uniquingKeysWith: { _, redacted in redacted }
            )
        }
        if let array = object as? [Any] { return array.map { redact($0) } }
        return object
    }
}
