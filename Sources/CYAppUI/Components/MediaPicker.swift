#if canImport(UIKit)
import SwiftUI
import PhotosUI

// MARK: - 媒体选择器
//
// 统一封装图片选择（相册）和拍照功能，支持：
// - 仅相册 / 仅拍照 / 两者皆可
// - 单选 / 多选 + 数量限制
// - 图片 / 视频 / 混合
// - 返回 UIImage 或 Data
//
// ## 相册选图（原生 PhotosPicker）
// ```swift
// struct ProfileView: View {
//     @State private var selectedImages: [UIImage] = []
//
//     var body: some View {
//         CYMediaPicker(
//             source: .album,
//             maxSelection: 3,
//             filter: .images
//         ) { images in
//             selectedImages = images
//         } label: {
//             Label("选择图片", systemImage: "photo.on.rectangle")
//         }
//     }
// }
// ```
//
// ## 拍照
// ```swift
// CYMediaPicker(source: .camera) { images in
//     avatarImage = images.first
// } label: {
//     Label("拍照", systemImage: "camera")
// }
// ```
//
// ## 相册 + 拍照（自动弹出 ActionSheet 让用户选择）
// ```swift
// CYMediaPicker(source: .both, maxSelection: 9) { images in
//     selectedImages = images
// } label: {
//     Label("添加图片", systemImage: "plus.circle")
// }
// ```

// MARK: - 数据源类型

/// 媒体选择来源
public enum CYMediaSource: Sendable {
    /// 仅相册
    case album
    /// 仅拍照
    case camera
    /// 两者皆可（弹出 ActionSheet 让用户选择）
    case both
}

/// 媒体类型过滤
public enum CYMediaFilter: Sendable {
    /// 仅图片
    case images
    /// 仅视频
    case videos
    /// 图片和视频
    case any
}

// MARK: - MediaPicker 组件

/// 统一的媒体选择器组件
///
/// 内部根据 `source` 自动选择 `PhotosPicker`（相册）或 `UIImagePickerController`（拍照）。
/// 当 `source = .both` 时，点击后弹出 ActionSheet 让用户选择来源。
public struct CYMediaPicker<Label: View>: View {
    
    let source: CYMediaSource
    let maxSelection: Int
    let filter: CYMediaFilter
    let onPicked: ([UIImage]) -> Void
    let label: () -> Label
    
    @State private var showCamera = false
    @State private var showSourceSheet = false
    @State private var photoItems: [PhotosPickerItem] = []
    
    public init(
        source: CYMediaSource = .both,
        maxSelection: Int = 1,
        filter: CYMediaFilter = .images,
        onPicked: @escaping ([UIImage]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = source
        self.maxSelection = maxSelection
        self.filter = filter
        self.onPicked = onPicked
        self.label = label
    }
    
    public var body: some View {
        Group {
            switch source {
            case .album:
                albumPicker
            case .camera:
                cameraButton
            case .both:
                bothButton
            }
        }
        // 拍照 Sheet
        .sheet(isPresented: $showCamera) {
            CYCameraView { image in
                if let image { onPicked([image]) }
            }
            .ignoresSafeArea()
        }
        // 选择来源 ActionSheet
        .confirmationDialog("选择来源", isPresented: $showSourceSheet) {
            Button("相册") { photoItems = [] ; triggerAlbumPicker = true }
            Button("拍照") { showCamera = true }
            Button("取消", role: .cancel) {}
        }
        // 相册选择（通过 PhotosPicker 的 programmatic 方式）
        .photosPicker(
            isPresented: $triggerAlbumPicker,
            selection: $photoItems,
            maxSelectionCount: maxSelection,
            matching: photoFilter,
            photoLibrary: .shared()
        )
        .onChange(of: photoItems) { _, newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if !images.isEmpty {
                    onPicked(images)
                }
            }
        }
    }
    
    @State private var triggerAlbumPicker = false
    
    // MARK: - 相册选择器
    
    private var albumPicker: some View {
        Button { triggerAlbumPicker = true } label: { label() }
    }
    
    // MARK: - 拍照按钮
    
    private var cameraButton: some View {
        Button { showCamera = true } label: { label() }
    }
    
    // MARK: - 两者皆可按钮
    
    private var bothButton: some View {
        Button { showSourceSheet = true } label: { label() }
    }
    
    // MARK: - 过滤器转换
    
    private var photoFilter: PHPickerFilter {
        switch filter {
        case .images: return .images
        case .videos: return .videos
        case .any: return .any(of: [.images, .videos])
        }
    }
}

// MARK: - 拍照桥接（UIViewControllerRepresentable）

/// UIImagePickerController 的 SwiftUI 桥接
///
/// 封装系统相机，处理拍照回调和生命周期。
/// 仅在 iOS 设备上有实际功能，模拟器上会显示提示。
public struct CYCameraView: UIViewControllerRepresentable {
    
    let onImagePicked: (UIImage?) -> Void
    
    public init(onImagePicked: @escaping (UIImage?) -> Void) {
        self.onImagePicked = onImagePicked
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        
        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage 扩展

public extension UIImage {
    /// 压缩图片到指定最大尺寸（KB）
    /// - Parameter maxKB: 最大文件大小（千字节）
    /// - Returns: 压缩后的 Data
    func compressedData(maxKB: Int = 500) -> Data? {
        var quality: CGFloat = 1.0
        var data = self.jpegData(compressionQuality: quality)
        
        while let imageData = data, imageData.count > maxKB * 1024, quality > 0.1 {
            quality -= 0.1
            data = self.jpegData(compressionQuality: quality)
        }
        
        return data
    }
    
    /// 缩放到指定最大宽度，保持宽高比
    /// - Parameter maxWidth: 最大宽度
    /// - Returns: 缩放后的 UIImage
    func scaledToMaxWidth(_ maxWidth: CGFloat) -> UIImage {
        guard size.width > maxWidth else { return self }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
