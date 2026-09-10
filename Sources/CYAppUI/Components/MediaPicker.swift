#if canImport(UIKit) && canImport(PhotosUI)
import SwiftUI
import PhotosUI
import Photos
import CYAppCore
import CYAppDesignSystem

// MARK: - 统一媒体选择器入口
//
// 两种样式：
//
// ## .grid（推荐，仿微信）
// 自定义网格选择器，支持选择状态保留、相册切换、原图选项、全屏预览。
// ```swift
// @State private var selectedIds: [String] = []
//
// CYMediaPicker(
//     maxSelection: 9,
//     allowsCamera: true,
//     allowsOriginal: true,
//     preselected: selectedIds    // 保留上次选择
// ) { items in
//     selectedIds = items.localIdentifiers  // 存储供下次恢复
//     Task {
//         let images = await items.loadImages()
//         // 使用 images
//     }
// } label: {
//     Label("添加图片", systemImage: "plus.circle")
// }
// ```
//
// ## .system（简单场景）
// 系统原生 PhotosPicker + UIImagePickerController。
// 轻量，但无法保留选择状态。
// ```swift
// CYMediaPicker(
//     style: .system,
//     source: .both,
//     maxSelection: 3
// ) { items in
//     Task {
//         let images = await items.loadImages()
//     }
// } label: {
//     Label("选择图片", systemImage: "photo.on.rectangle")
// }
// ```

/// 统一媒体选择器组件
public struct CYMediaPicker<Label: View>: View {

    // MARK: - 配置

    let style: CYMediaPickerStyle
    let source: CYMediaSource
    let maxSelection: Int
    let filter: CYMediaFilter
    let allowsCamera: Bool
    let allowsOriginal: Bool
    let preselected: [String]
    private let selectionIDs: Binding<[String]>?
    let onPicked: ([CYMediaItem]) -> Void
    let label: () -> Label

    // MARK: - Grid 样式状态

    @State private var showGridPicker = false
    /// 当前组件生命周期内最后一次确认的相册选择，用于再次打开时回显。
    @State private var retainedSelectionIDs: [String] = []

    // MARK: - System 样式状态

    @State private var showCamera = false
    @State private var showSourceSheet = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var triggerAlbumPicker = false

    // MARK: - 初始化

    /// 网格样式初始化（推荐，仿微信）
    public init(
        style: CYMediaPickerStyle = .grid,
        maxSelection: Int = 1,
        filter: CYMediaFilter = .images,
        allowsCamera: Bool = true,
        allowsOriginal: Bool = false,
        preselected: [String] = [],
        onPicked: @escaping ([CYMediaItem]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.style = style
        self.source = .both
        self.maxSelection = maxSelection
        self.filter = filter
        self.allowsCamera = allowsCamera
        self.allowsOriginal = allowsOriginal
        self.preselected = preselected
        self.selectionIDs = nil
        self.onPicked = onPicked
        self.label = label
    }

    /// 网格样式初始化（自动保留确认后的多选状态）
    public init(
        style: CYMediaPickerStyle = .grid,
        maxSelection: Int = 1,
        filter: CYMediaFilter = .images,
        allowsCamera: Bool = true,
        allowsOriginal: Bool = false,
        selectionIDs: Binding<[String]>,
        onPicked: @escaping ([CYMediaItem]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.style = style
        self.source = .both
        self.maxSelection = maxSelection
        self.filter = filter
        self.allowsCamera = allowsCamera
        self.allowsOriginal = allowsOriginal
        self.preselected = []
        self.selectionIDs = selectionIDs
        self.onPicked = onPicked
        self.label = label
    }

    /// 系统样式初始化（source 参数仅 .system 生效）
    public init(
        style: CYMediaPickerStyle = .grid,
        source: CYMediaSource = .both,
        maxSelection: Int = 1,
        filter: CYMediaFilter = .images,
        onPicked: @escaping ([CYMediaItem]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.style = style
        self.source = source
        self.maxSelection = maxSelection
        self.filter = filter
        self.allowsCamera = source != .album
        self.allowsOriginal = false
        self.preselected = []
        self.selectionIDs = nil
        self.onPicked = onPicked
        self.label = label
    }

    public var body: some View {
        Group {
            switch style {
            case .grid:
                gridStyleBody
            case .system:
                systemStyleBody
            }
        }
    }

    // MARK: - Grid 样式

    private var gridStyleBody: some View {
        Button { showGridPicker = true } label: { label() }
            .fullScreenCover(isPresented: $showGridPicker) {
                CYMediaPickerController(
                    maxSelection: maxSelection,
                    allowsCamera: allowsCamera,
                    allowsOriginal: allowsOriginal,
                    filter: filter,
                    preselected: restoredSelectionIDs,
                    onConfirm: { items in
                        let identifiers = items.localIdentifiers
                        retainedSelectionIDs = identifiers
                        selectionIDs?.wrappedValue = identifiers

                        showGridPicker = false
                        onPicked(items)
                    },
                    onCancel: {
                        showGridPicker = false
                    }
                )
            }
    }

    private var restoredSelectionIDs: [String] {
        if let selectionIDs {
            return selectionIDs.wrappedValue
        }
        return retainedSelectionIDs.isEmpty ? preselected : retainedSelectionIDs
    }

    // MARK: - System 样式

    private var systemStyleBody: some View {
        Group {
            switch source {
            case .album:
                systemAlbumButton
            case .camera:
                systemCameraButton
            case .both:
                systemBothButton
            }
        }
        .sheet(isPresented: $showCamera) {
            CYCameraView { image in
                showCamera = false
                if let image {
                    onPicked([CYMediaItem(image: image)])
                }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("source_picker_title".cyLocalized, isPresented: $showSourceSheet) {
            Button("album".cyLocalized) { photoItems = []; triggerAlbumPicker = true }
            if CYCameraView.isCameraAvailable {
                Button("camera".cyLocalized) { showCamera = true }
            }
            Button("cancel".cyLocalized, role: .cancel) {}
        }
        .photosPicker(
            isPresented: $triggerAlbumPicker,
            selection: $photoItems,
            maxSelectionCount: maxSelection,
            matching: photoFilter,
            photoLibrary: .shared()
        )
        .onChange(of: photoItems) { _, newItems in
            Task {
                var images: [CYMediaItem] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(CYMediaItem(image: image))
                    }
                }
                if !images.isEmpty {
                    onPicked(images)
                }
            }
        }
    }

    private var systemAlbumButton: some View {
        Button { photoItems = []; triggerAlbumPicker = true } label: { label() }
    }

    private var systemCameraButton: some View {
        Button {
            guard CYCameraView.isCameraAvailable else { return }
            showCamera = true
        } label: { label() }
    }

    private var systemBothButton: some View {
        Button { showSourceSheet = true } label: { label() }
    }

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
/// 仅在 iOS 设备上有实际功能，模拟器 / 无相机设备会自动显示提示而非崩溃。
public struct CYCameraView: UIViewControllerRepresentable {

    let onImagePicked: (UIImage?) -> Void

    /// 当前设备是否支持相机（模拟器返回 false）
    public static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    public init(onImagePicked: @escaping (UIImage?) -> Void) {
        self.onImagePicked = onImagePicked
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        guard CYCameraView.isCameraAvailable else {
            let alert = UIAlertController(
                title: "camera_unavailable_title".cyLocalized,
                message: "camera_unavailable_message".cyLocalized,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "confirm".cyLocalized, style: .default) { _ in
                context.coordinator.onImagePicked(nil)
            })
            return alert
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // 仅通过回调驱动外层 SwiftUI fullScreenCover/sheet 关闭，
            // 避免 UIKit dismiss 与 showCamera = false 双重关闭导致崩溃。
            let image = info[.originalImage] as? UIImage
            DispatchQueue.main.async { [onImagePicked] in
                onImagePicked(image)
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async { [onImagePicked] in
                onImagePicked(nil)
            }
        }
    }
}

// MARK: - UIImage 扩展

public extension UIImage {
    /// 压缩图片到指定最大尺寸（KB）
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
