import Foundation

// MARK: - Bundle 扩展
//
// 从 Bundle 中解码 JSON 文件，常用于加载本地配置数据。
//
// 用法：
// ```swift
// let config: AppConfig = Bundle.main.decode("config.json")
// ```

extension Bundle {
    
    /// 从 Bundle 中解码 JSON 文件为 Decodable 类型
    /// - Parameter file: 文件名（含扩展名）
    public func decode<T: Decodable>(_ file: String) -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("Failed to locate \(file) in bundle.")
        }

        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed to load \(file) from bundle.")
        }

        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(formatter)

        guard let loaded = try? decoder.decode(T.self, from: data) else {
            fatalError("Failed to decode \(file) from bundle.")
        }

        return loaded
    }
}
