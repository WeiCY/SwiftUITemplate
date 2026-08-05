import Foundation

// MARK: - 图片加载协议

public protocol CYImageLoaderProtocol: Sendable {
    func loadImage(from url: URL) async throws -> Data
    func prefetch(urls: [URL])
    func clearCache()
}

// MARK: - 图片加载错误

public enum ImageLoaderError: Error, LocalizedError {
    case decodeFailed
    case loadFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .decodeFailed: return "图片数据解码失败"
        case .loadFailed(let error): return "图片加载失败: \(error.localizedDescription)"
        }
    }
}
