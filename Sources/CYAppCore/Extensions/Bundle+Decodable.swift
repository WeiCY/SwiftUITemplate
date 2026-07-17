import Foundation

// MARK: - Bundle 解码错误

/// 从 Bundle 解码 JSON 时可能出现的错误
public enum CYBundleDecodingError: Error {
    /// 在 Bundle 中找不到指定文件
    case fileNotFound(String)
    /// 读取文件内容失败
    case loadFailed(String)
    /// JSON 解析失败
    case decodeFailed(String)
}

// MARK: - Bundle 扩展
//
// 从 Bundle 中解码 JSON 文件，常用于加载本地配置数据。
//
// 用法：
// ```swift
// let config: AppConfig = try Bundle.main.decode("config.json")
// ```

extension Bundle {
    
    /// 从 Bundle 中解码 JSON 文件为 Decodable 类型
    /// - Parameter file: 文件名（含扩展名）
    /// - Returns: 解码后的对象
    /// - Throws: 文件缺失、读取失败或解析失败时抛出 `CYBundleDecodingError`
    public func decode<T: Decodable>(_ file: String) throws -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            throw CYBundleDecodingError.fileNotFound(file)
        }

        guard let data = try? Data(contentsOf: url) else {
            throw CYBundleDecodingError.loadFailed(file)
        }

        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(formatter)

        guard let loaded = try? decoder.decode(T.self, from: data) else {
            throw CYBundleDecodingError.decodeFailed(file)
        }

        return loaded
    }
}
