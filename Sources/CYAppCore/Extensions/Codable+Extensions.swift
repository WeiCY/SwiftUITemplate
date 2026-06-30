import Foundation

// MARK: - Codable 扩展
//
// 为 Encodable 类型提供 JSON 调试输出。
//
// 用法：
// ```swift
// let user = User(id: 1, name: "Test")
// print(user.prettyJSON)  // 格式化的 JSON 字符串
// ```

extension Encodable {
    
    /// 返回格式化的 JSON 字符串（调试用）
    public var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "Error encoding JSON"
        }
        return string
    }
}
