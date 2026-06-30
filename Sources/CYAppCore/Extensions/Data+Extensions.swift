import Foundation

// MARK: - Data 扩展
//
// 提供 Data 的编码、JSON 转换、可读大小等常用操作。
//
// 用法：
// ```swift
// data.hexString           // "48656c6c6f"
// data.prettyJSON          // 格式化 JSON 字符串
// data.humanReadableSize   // "1.5 MB"
// try data.decoded(as: User.self)
// ```

extension Data {
    
    // MARK: - 编码
    
    /// Base64 编码字符串
    public var base64String: String {
        return base64EncodedString()
    }
    
    /// 十六进制字符串
    public var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - JSON
    
    /// 格式化的 JSON 字符串（调试用）
    public var prettyJSON: String {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return string
    }
    
    /// 解码为指定 Decodable 类型
    /// 用法: let user = try data.decoded(as: User.self)
    public func decoded<T: Decodable>(as type: T.Type, decoder: JSONDecoder = .init()) throws -> T {
        return try decoder.decode(T.self, from: self)
    }
    
    /// 转换为字典（如果是合法 JSON）
    public var asDictionary: [String: Any]? {
        return try? JSONSerialization.jsonObject(with: self) as? [String: Any]
    }
    
    /// 转换为 UTF-8 字符串
    public var asString: String? {
        return String(data: self, encoding: .utf8)
    }
    
    // MARK: - 大小
    
    /// 人类可读的文件大小（如 "1.5 MB"）
    public var humanReadableSize: String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(count))
    }
}
