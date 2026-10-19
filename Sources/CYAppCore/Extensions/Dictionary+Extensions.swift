import Foundation

// MARK: - Dictionary 扩展
//
// 提供查询参数转换、JSON 调试输出。原生merge/merging显式选择冲突策略。
//
// 用法：
// ```swift
// let params = ["key": "value", "page": "1"]
// params.queryString               // "key=value&page=1"
// params.prettyJSON                // 格式化 JSON
// ```

extension Dictionary where Key == String {
    
    /// 转换为 URL 查询参数字符串
    /// 用法: ["key": "value", "page": "1"].queryString → "key=value&page=1"
    public var queryString: String {
        return map { "\($0.key.urlEncoded)=\("\($0.value)".urlEncoded)" }.joined(separator: "&")
    }
    
    /// 转换为 JSON Data
    public var jsonData: Data? {
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }
    
    /// 转换为**格式化（缩进）**的 JSON 字符串；无效时返回 "Invalid JSON"
    public var prettyJSON: String {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return string
    }
}
