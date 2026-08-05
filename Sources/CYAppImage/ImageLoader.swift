import Foundation
import Kingfisher
import FactoryKit
import CYAppCore

// MARK: - 注册到 DI

public enum CYAppImageConfig {
    /// 注册 Kingfisher 图片加载器到 DI 容器
    public static func configure() {
        Container.shared.imageLoader.register { CYKingfisherImageLoader.shared }
    }
}

// MARK: - 跨平台 PNG 数据扩展

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif

// MARK: - Kingfisher 实现

/// Kingfisher 图片加载器实现
public final class CYKingfisherImageLoader: CYImageLoaderProtocol, @unchecked Sendable {
    
    public nonisolated static let shared = CYKingfisherImageLoader()
    
    private let manager = KingfisherManager.shared
    
    public init() {}
    
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
    
    public func prefetch(urls: [URL]) {
        let prefetcher = ImagePrefetcher(urls: urls)
        prefetcher.start()
    }
    
    public func clearCache() {
        manager.cache.clearMemoryCache()
        manager.cache.clearDiskCache(completion: nil)
    }
}
