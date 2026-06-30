import Foundation
import Kingfisher

// MARK: - 跨平台 PNG 数据扩展

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
extension NSImage {
    /// 跨平台兼容 pngData()
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif

// MARK: - 图片加载器
//
// 封装图片加载、预加载、缓存管理，业务代码只依赖 CYImageLoaderProtocol。
// 内部使用 Kingfisher 实现，对外不暴露 Kingfisher 类型。
//
// 用法：
// ```swift
// let loader = CYKingfisherImageLoader.shared
// let data = try await loader.loadImage(from: url)
// loader.prefetch(urls: imageURLs)
// loader.clearCache()
// ```

// MARK: - 图片加载协议

/// 图片加载协议，业务代码只依赖此协议
public protocol CYImageLoaderProtocol: Sendable {
    /// 加载图片数据
    func loadImage(from url: URL) async throws -> Data
    /// 预加载多张图片
    func prefetch(urls: [URL])
    /// 清除缓存
    func clearCache()
}

// MARK: - Kingfisher 实现（桥接层）

/// Kingfisher 图片加载器实现
/// 内部使用 Kingfisher，对外只暴露 CYImageLoaderProtocol
public final class CYKingfisherImageLoader: CYImageLoaderProtocol, @unchecked Sendable {
    
    public nonisolated static let shared = CYKingfisherImageLoader()
    
    private let manager = KingfisherManager.shared
    
    public init() {}
    
    /// 异步加载图片并返回 Data
    public func loadImage(from url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            manager.retrieveImage(with: .network(url)) { result in
                switch result {
                case .success(let value):
                    if let data = value.image.pngData() {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: ImageLoaderError.decodeFailed)
                    }
                case .failure(let error):
                    continuation.resume(throwing: ImageLoaderError.loadFailed(error))
                }
            }
        }
    }
    
    /// 预加载多张图片
    public func prefetch(urls: [URL]) {
        let prefetcher = ImagePrefetcher(urls: urls)
        prefetcher.start()
    }
    
    /// 清除内存和磁盘缓存
    public func clearCache() {
        manager.cache.clearMemoryCache()
        manager.cache.clearDiskCache(completion: nil)
    }
}

// MARK: - 图片加载错误

/// 图片加载错误类型
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
