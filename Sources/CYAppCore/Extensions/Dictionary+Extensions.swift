import Foundation

// MARK: - Dictionary 扩展
//
// 提供字典的合并、查询参数转换、JSON 序列化等常用操作。
//
// 用法：
// ```swift
// var dict = ["a": 1, "b": 2]
// dict.merge(["c": 3])             // ["a":1, "b":2, "c":3]
// dict.hasKey("a")                 // true
//
// let params = ["key": "value", "page": "1"]
// params.queryString               // "key=value&page=1"
// params.prettyJSON                // 格式化 JSON
// ```

extension Dictionary {
    
    /// 是否非空
    public var isNotEmpty: Bool {
        return !isEmpty
    }
    
    /// 类型安全地获取值
    public func value<T>(for key: Key) -> T? {
        return self[key] as? T
    }
    
    /// 合并另一个字典（冲突时后者覆盖）
    public mutating func merge(_ other: [Key: Value]) {
        for (key, value) in other {
            self[key] = value
        }
    }
    
    /// 返回合并后的新字典
    public func merged(with other: [Key: Value]) -> [Key: Value] {
        var result = self
        result.merge(other)
        return result
    }
    
    /// 是否包含指定的 key
    public func hasKey(_ key: Key) -> Bool {
        return self[key] != nil
    }
    
    /// 所有 key 转为数组
    public var keysArray: [Key] {
        return Array(keys)
    }
    
    /// 所有 value 转为数组
    public var valuesArray: [Value] {
        return Array(values)
    }
}

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
    
    /// 转换为格式化的 JSON 字符串
    public var prettyJSON: String {
        guard let data = jsonData,
              let string = String(data: data, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return string
    }
}
