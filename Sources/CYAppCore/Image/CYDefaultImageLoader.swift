import Foundation

// MARK: - 默认图片加载器

/// CYAppCore 内置的轻量图片加载器，基于 `URLSession`。
///
/// 作用：
/// - 当业务项目只依赖 `CYAppCore` 时，也能让 `CYRemoteImageView` 等组件正常工作；
/// - 不需要强制导入 `CYAppImage` 并手动注册 `CYAppImageConfig.configure()`；
/// - 导入 `CYAppImage` 后，Kingfisher 实现会通过 DI 覆盖该默认实现。
public actor CYDefaultImageLoader: CYImageLoaderProtocol {

    public nonisolated static let shared = CYDefaultImageLoader()

    public init() {}

    public func loadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ImageLoaderError.loadFailed(URLError(.badServerResponse))
        }
        return data
    }

    public nonisolated func prefetch(urls: [URL]) {
        // URLSession 默认实现不主动预加载，业务可替换为 Kingfisher 的 ImagePrefetcher。
    }

    public nonisolated func clearCache() {
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
    }
}
