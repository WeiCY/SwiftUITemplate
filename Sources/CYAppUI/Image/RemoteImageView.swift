#if canImport(UIKit)
import SwiftUI
import CYAppCore

/// 远程图片视图
/// 通过 CYImageLoaderProtocol 加载图片，不直接依赖 Kingfisher
/// 替换 Kingfisher 时只需更换 ImageLoader 实现即可
public struct CYRemoteImageView: View {
    let url: URL?
    let placeholder: Image?
    let contentMode: SwiftUI.ContentMode
    let imageLoader: CYImageLoaderProtocol
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var retryCount = 0
    private let maxRetries = 3
    
    public init(
        url: URL?,
        placeholder: Image? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        imageLoader: CYImageLoaderProtocol = CYKingfisherImageLoader.shared
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.imageLoader = imageLoader
    }
    
    public var body: some View {
        ZStack {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(CYAppColor.textSecondary)
                    Text("image_load_failed".cyLocalized)
                        .font(CYAppFont.caption)
                        .foregroundStyle(CYAppColor.textSecondary)
                    Button("重试") {
                        Task { await loadImage() }
                    }
                    .font(CYAppFont.caption)
                }
            } else if let placeholder {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    // MARK: - 私有方法
    
    /// 加载图片，最多重试 `maxRetries` 次（指数退避）。
    /// 循环代替递归以避免栈增长，并在每次重试前检查 `Task.isCancelled`。
    private func loadImage() async {
        guard let url else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        var attempt = 0
        while attempt <= maxRetries {
            if Task.isCancelled { return }
            
            do {
                let data = try await imageLoader.loadImage(from: url)
                if Task.isCancelled { return }
                if let image = UIImage(data: data) {
                    loadedImage = image
                    error = nil
                    return
                }
                throw NSError(
                    domain: "CYRemoteImageView",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "图片数据解析失败"]
                )
            } catch {
                if Task.isCancelled { return }
                self.error = error
                attempt += 1
                if attempt <= maxRetries {
                    do {
                        try await Task.sleep(for: .seconds(min(Double(attempt), 3)))
                    } catch {
                        return
                    }
                }
            }
        }
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
#endif
