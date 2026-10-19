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

// MARK: - Kingfisher 实现

/// Kingfisher 图片加载器实现
public final class CYKingfisherImageLoader: CYImageLoaderProtocol, Sendable {
    
    public nonisolated static let shared = CYKingfisherImageLoader()
    
    private let manager: KingfisherManager
    
    public init(manager: KingfisherManager = .shared) { self.manager = manager }
    
    public func loadImage(from url: URL) async throws -> Data {
        let state = CYImageRequestState()
        let data = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                state.install(continuation)
                let task = manager.retrieveImage(
                    with: .network(url),
                    options: [.callbackQueue(.dispatch(.global(qos: .userInitiated)))],
                    downloadTaskUpdated: { task in
                        if let task { state.setCancellation { task.cancel() } }
                    }
                ) { result in
                    switch result {
                    case .success(let value):
                        if let data = value.data() { state.complete(.success(data)) } else { state.complete(.failure(ImageLoaderError.decodeFailed)) }
                    case .failure(let error):
                        state.complete(.failure(error.isTaskCancelled ? CancellationError() : ImageLoaderError.loadFailed(error)))
                    }
                }
                if let task { state.setCancellation { task.cancel() } }
            }
        } onCancel: {
            state.cancel()
        }
        try Task.checkCancellation()
        return data
    }

    public func prefetch(urls: [URL]) {
        let prefetcher = ImagePrefetcher(urls: urls, options: [.downloader(manager.downloader), .targetCache(manager.cache)])
        prefetcher.start()
    }
    
    public func clearCache() {
        manager.cache.clearMemoryCache()
        manager.cache.clearDiskCache(completion: nil)
    }
}
