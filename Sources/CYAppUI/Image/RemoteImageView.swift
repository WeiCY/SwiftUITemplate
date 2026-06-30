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
    
    private func loadImage() async {
        guard let url else { return }
        isLoading = true
        error = nil
        
        do {
            let data = try await imageLoader.loadImage(from: url)
            if let image = UIImage(data: data) {
                loadedImage = image
            }
        } catch {
            self.error = error
            if retryCount < maxRetries {
                retryCount += 1
                try? await Task.sleep(for: .seconds(retryCount))
                await loadImage()
            }
        }
        
        isLoading = false
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
