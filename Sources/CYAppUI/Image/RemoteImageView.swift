import SwiftUI
import Observation
import CYAppCore
import CYAppDesignSystem

#if canImport(UIKit)
import UIKit

typealias CYPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit

typealias CYPlatformImage = NSImage
#endif

private extension Image {
    init(cyPlatformImage: CYPlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: cyPlatformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: cyPlatformImage)
        #endif
    }
}

/// 远程图片视图
///
/// 通过 `CYImageLoaderProtocol` 加载图片，不直接依赖 Kingfisher。
/// 替换图片实现时只需更换 ImageLoader 即可（iOS / macOS 均可编译）。
public struct CYRemoteImageView: View {
    let url: URL?
    let placeholder: Image?
    let contentMode: SwiftUI.ContentMode
    let imageLoader: CYImageLoaderProtocol
    let maxRetries: Int
    let retryDelay: TimeInterval
    let errorRetryTitle: String

    public init(
        url: URL?,
        placeholder: Image? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        imageLoader: CYImageLoaderProtocol = CYAppContainer.shared.imageLoader,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 0.5,
        errorRetryTitle: String = "image_retry"
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.imageLoader = imageLoader
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.errorRetryTitle = errorRetryTitle
    }

    public var body: some View {
        RemoteImageContent(
            url: url, placeholder: placeholder, contentMode: contentMode,
            imageLoader: imageLoader, maxRetries: max(0, maxRetries),
            retryDelay: max(0, retryDelay), errorRetryTitle: errorRetryTitle
        )
        // URL 是资源身份：更换 URL 时立即销毁旧图片、错误和重试状态。
        .id(url)
    }
}

private struct RemoteImageContent: View {
    let url: URL?
    let placeholder: Image?
    let contentMode: SwiftUI.ContentMode
    let imageLoader: CYImageLoaderProtocol
    let maxRetries: Int
    let retryDelay: TimeInterval
    let errorRetryTitle: String
    @State private var state = CYRemoteImageLoadState()
    @State private var retryID = UUID()

    public var body: some View {
        ZStack {
            if let loadedImage = state.loadedImage {
                Image(cyPlatformImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if state.error != nil {
                errorView
            } else if let placeholder {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if url == nil {
                Color.clear
            } else {
                ProgressView()
            }
        }
        .task(id: retryID) {
            await state.load(url: url, imageLoader: imageLoader, maxRetries: maxRetries, retryDelay: retryDelay)
        }
    }

    // MARK: - 错误视图

    private var errorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(CYAppColor.textSecondary)
            Text("image_load_failed".cyLocalized)
                .font(CYAppFont.caption)
                .foregroundStyle(CYAppColor.textSecondary)
            Button(errorRetryTitle.cyLocalized) {
                retryID = UUID()
            }
            .font(CYAppFont.caption)
        }
    }

}

/// 加载状态单独管理请求身份，防止被取消但未立即退出的加载器提交旧结果。
@MainActor
@Observable
final class CYRemoteImageLoadState {
    private(set) var loadedImage: CYPlatformImage?
    private(set) var error: Error?
    @ObservationIgnored private var requestID = UUID()

    // MARK: - 私有方法

    /// 加载图片，最多重试 `maxRetries` 次（线性退避）。
    /// 循环代替递归以避免栈增长，并在每次重试前检查 `Task.isCancelled`。
    func load(url: URL?, imageLoader: CYImageLoaderProtocol, maxRetries: Int, retryDelay: TimeInterval) async {
        let id = UUID()
        requestID = id
        loadedImage = nil
        error = nil
        guard let url else { return }

        var attempt = 0
        while attempt <= max(0, maxRetries) {
            if Task.isCancelled || requestID != id { return }

            do {
                let data = try await imageLoader.loadImage(from: url)
                if Task.isCancelled || requestID != id { return }
                if let image = Self.makeImage(from: data) {
                    loadedImage = image
                    error = nil
                    return
                }
                throw NSError(
                    domain: "CYRemoteImageView",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "image_decode_failed".cyLocalized]
                )
            } catch {
                if Task.isCancelled || requestID != id { return }
                self.error = error
                attempt += 1
                if attempt <= max(0, maxRetries) {
                    do {
                        let delay = max(0, retryDelay) * TimeInterval(attempt)
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        return
                    }
                }
            }
        }
    }

    private static func makeImage(from data: Data) -> CYPlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        CYRemoteImageView(
            url: URL(string: "https://picsum.photos/400/200"),
            contentMode: .fit
        )
        .frame(height: 200)
        .background(Color.gray.opacity(0.1))

        CYRemoteImageView(
            url: URL(string: "https://picsum.photos/100/100"),
            contentMode: .fill
        )
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }
}
