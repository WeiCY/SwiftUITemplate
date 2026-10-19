import Foundation

extension URLRequest {
    /// 调试用 cURL；默认按模板日志规则脱敏 URL、Header 和 JSON Body，并进行 shell 单引号转义。
    /// 非 JSON Body 默认隐藏；不包含流式 Body。秘密不应放入普通字段或 URL 路径。
    public var cURL: String { cURL(redactingSensitiveData: true) }

    /// 原文仅用于本地排查；redactingSensitiveData 为 false 时会包含凭证，不应写入日志。
    public func cURL(redactingSensitiveData: Bool) -> String {
        guard let url else { return "" }
        let address = redactingSensitiveData ? CYNetworkLogRedactor.url(url.absoluteString) : url.absoluteString
        var command = ["curl \(Self.shellQuoted(address))"]
        if httpMethod == "HEAD" { command.append("--head") }
        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(Self.shellQuoted(method))")
        }
        for (key, value) in (allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            let value = redactingSensitiveData && CYNetworkLogRedactor.isSensitive(key) ? "***" : value
            command.append("-H \(Self.shellQuoted("\(key): \(value)"))")
        }
        if let data = httpBody {
            let body = redactingSensitiveData ? CYNetworkLogRedactor.body(data) : String(data: data, encoding: .utf8)
            if let body { command.append("--data-raw \(Self.shellQuoted(body))") }
        }
        return command.joined(separator: " \\\n\t")
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
