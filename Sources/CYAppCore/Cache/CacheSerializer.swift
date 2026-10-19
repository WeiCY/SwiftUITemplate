import Foundation

// MARK: - 缓存序列化器协议

/// 缓存序列化器协议
///
/// 允许自定义缓存的序列化方式，支持 JSON、PropertyList、二进制等多种格式。
/// 默认使用 JSON；需要二进制属性列表时可选择 CYPropertyListSerializer，性能取决于实际数据。
public protocol CYCacheSerializer: Sendable {
    /// 序列化对象为 Data
    func serialize<T: Codable>(_ value: T) throws -> Data
    
    /// 从 Data 反序列化对象
    func deserialize<T: Codable>(_ data: Data, as type: T.Type) throws -> T
}

// MARK: - JSON 序列化器（默认）

/// JSON 序列化器（默认实现）
///
/// 适合 JSON 可表示的 Codable 数据；NaN/Infinity 等值默认抛编码错误。
public struct CYJSONSerializer: CYCacheSerializer {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public func serialize<T: Codable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    public func deserialize<T: Codable>(_ data: Data, as type: T.Type) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

// MARK: - PropertyList 序列化器（高性能）

/// 二进制 PropertyList 序列化器，支持自定义 Codable 结构及嵌套。
/// 与 JSON 的数值/日期/顶层类型支持不同；切换前应对真实模型执行往返测试。
/// 尚无仓库可复现的跨格式性能测量，不承诺速度或体积比例。
public struct CYPropertyListSerializer: CYCacheSerializer {
    public init() {}
    
    public func serialize<T: Codable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary  // 明确选择二进制格式
        return try encoder.encode(value)
    }
    
    public func deserialize<T: Codable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = PropertyListDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
