#if canImport(UIKit) && canImport(Photos)
import SwiftUI
import Photos
import CYAppCore
import CYAppDesignSystem

// MARK: - 微信风格媒体选择器（全屏容器）
//
// 布局：
// ```
// ┌─────────────────────────────┐
// │ [取消]  所有照片 [▾]        │  导航栏 + 相册切换
// ├─────────────────────────────┤
// │ [📷] [img] [img] [img]      │  4列网格，拍照在首位
// │ [img] [img] [img] [img]      │
// │ ...                          │
// ├─────────────────────────────┤
// │ [预览]    原图☑    完成(3/9) │  底部栏
// └─────────────────────────────┘
// ```

/// 全屏媒体选择器
public struct CYMediaPickerController: View {

    // MARK: - 配置

    let maxSelection: Int
    let allowsCamera: Bool
    let allowsOriginal: Bool
    let filter: CYMediaFilter
    let preselected: [String]
    let onConfirm: ([CYMediaItem]) -> Void
    let onCancel: () -> Void

    // MARK: - 状态

    @State private var selectionManager: CYMediaSelectionManager
    @State private var showCamera = false
    @State private var showPreview = false
    @State private var showAlbumList = false
    @State private var previewIndex = 0
    @State private var currentAlbum = CYAlbumInfo.allPhotos
    @State private var albums: [CYAlbumInfo] = [.allPhotos]
    @State private var gridAssets: [PHAsset] = []
    @State private var permissionStatus: CYPermissionStatus = .notDetermined

    public init(
        maxSelection: Int = 9,
        allowsCamera: Bool = true,
        allowsOriginal: Bool = false,
        filter: CYMediaFilter = .images,
        preselected: [String] = [],
        onConfirm: @escaping ([CYMediaItem]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.maxSelection = maxSelection
        self.allowsCamera = allowsCamera
        self.allowsOriginal = allowsOriginal
        self.filter = filter
        self.preselected = preselected
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectionManager = State(initialValue: CYMediaSelectionManager(
            maxSelection: maxSelection,
            allowsOriginal: allowsOriginal
        ))
    }

    public var body: some View {
        Group {
            switch permissionStatus {
            case .authorized:
                contentView
            case .denied, .restricted:
                permissionDeniedView
            case .notDetermined:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CYAppColor.background)
            }
        }
        .task { await checkPermission() }
        .fullScreenCover(isPresented: $showCamera) {
            CYCameraView { image in
                showCamera = false
                if let image {
                    handleCapturedImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPreview) {
            CYPhotoPreviewView(
                assets: gridAssets,
                currentIndex: $previewIndex,
                selectionManager: selectionManager,
                onDone: {
                    showPreview = false
                    if selectionManager.hasSelection {
                        onConfirm(selectionManager.selectedItems)
                    }
                }
            )
        }
        .sheet(isPresented: $showAlbumList) {
            NavigationStack {
                CYAlbumListSheet(
                    albums: albums,
                    selectedAlbum: $currentAlbum
                ) { album in
                    showAlbumList = false
                    Task { await reloadAssets(for: album) }
                }
                .navigationTitle("media_albums".cyLocalized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("cancel".cyLocalized) { showAlbumList = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 主内容

    private var contentView: some View {
        NavigationStack {
            CYPhotoGridPicker(
                selectionManager: selectionManager,
                filter: filter,
                allowsCamera: allowsCamera,
                assets: gridAssets,
                onCamera: {
                    requestCameraPermission()
                },
                onPreview: { index in
                    previewIndex = index
                    showPreview = true
                },
                onMaxReached: {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            )
            .navigationTitle(currentAlbum.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .task {
            await loadAlbums()
            await reloadAssets(for: currentAlbum)
        }
        .task(id: preselected) {
            restoreSelection()
        }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("cancel".cyLocalized) { onCancel() }
        }
        ToolbarItem(placement: .principal) {
            Button { showAlbumList = true } label: {
                HStack(spacing: 4) {
                    Text(currentAlbum.title)
                        .font(CYAppFont.bodyMedium)
                        .foregroundStyle(CYAppColor.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CYAppColor.textSecondary)
                }
            }
        }
    }

    // MARK: - 底部栏

    private var bottomBar: some View {
        HStack(spacing: 0) {
            // 预览按钮
            Button {
                if let first = selectionManager.selectedItems.first,
                   let firstAsset = first.asset,
                   let index = gridAssets.firstIndex(of: firstAsset) {
                    previewIndex = index
                } else {
                    previewIndex = 0
                }
                showPreview = true
            } label: {
                Text("media_preview".cyLocalized)
                    .font(CYAppFont.bodyMedium)
                    .foregroundStyle(
                        selectionManager.hasSelection
                            ? CYAppColor.primary
                            : CYAppColor.textTertiary
                    )
            }
            .disabled(!selectionManager.hasSelection)

            Spacer()

            // 原图开关
            if allowsOriginal {
                Toggle(isOn: Binding(
                    get: { selectionManager.sendOriginal },
                    set: { selectionManager.sendOriginal = $0 }
                )) {
                    Text("media_original".cyLocalized)
                        .font(CYAppFont.bodyMedium)
                }
                .tint(CYAppColor.primary)
            }

            Spacer()

            // 完成按钮
            Button {
                onConfirm(selectionManager.selectedItems)
            } label: {
                Text(doneTitle)
                    .font(CYAppFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectionManager.hasSelection
                            ? CYAppColor.primary
                            : CYAppColor.secondaryBackground
                    )
                    .clipShape(Capsule())
            }
            .disabled(!selectionManager.hasSelection)
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.vertical, CYAppDimens.marginS)
        .background(CYAppColor.background)
    }

    private var doneTitle: String {
        selectionManager.hasSelection
            ? String(format: "media_done_count".cyLocalized, selectionManager.selectedCount)
            : "media_done".cyLocalized
    }

    // MARK: - 权限拒绝视图

    private var permissionDeniedView: some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(CYAppColor.textTertiary)

            Text("media_photo_permission_title".cyLocalized)
                .font(CYAppFont.h4)

            Text("media_photo_permission_message".cyLocalized)
                .font(CYAppFont.bodyMedium)
                .foregroundStyle(CYAppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CYAppDimens.marginXL)

            Button {
                CYPermissionManager.shared.openSettings()
            } label: {
                Text("media_go_to_settings".cyLocalized)
                    .font(CYAppFont.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, CYAppDimens.marginL)
                    .padding(.vertical, CYAppDimens.marginS)
                    .background(CYAppColor.primary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CYAppColor.background)
    }

    // MARK: - 权限处理

    private func checkPermission() async {
        let status = await CYPermissionManager.shared.status(of: .photoLibrary)
        permissionStatus = status
        if status == .notDetermined {
            permissionStatus = await CYPermissionManager.shared.request(.photoLibrary)
        }
    }

    private func requestCameraPermission() {
        Task {
            let status = await CYPermissionManager.shared.status(of: .camera)
            if status == .notDetermined {
                let result = await CYPermissionManager.shared.request(.camera)
                if result == .authorized {
                    showCamera = true
                }
            } else if status == .authorized {
                showCamera = true
            }
        }
    }

    // MARK: - 数据加载

    private func loadAlbums() async {
        albums = await CYPhotoAssetLoader.shared.fetchAlbums(filter: filter)
    }

    private func reloadAssets(for album: CYAlbumInfo) async {
        gridAssets = CYPhotoAssetLoader.shared.fetchAssets(in: album, filter: filter)
    }

    // MARK: - 选择状态恢复

    private func restoreSelection() {
        selectionManager.restore(from: preselected)
    }

    // MARK: - 拍照回调

    private func handleCapturedImage(_ image: UIImage) {
        // 直接添加到选择列表
        if selectionManager.canSelectMore {
            selectionManager.addCapturedImage(image)
        }

        // 同时保存到相册，使其出现在网格中
        saveToPhotoLibrary(image)
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        } completionHandler: { _, _ in
            Task { @MainActor in
                await reloadAssets(for: currentAlbum)
            }
        }
    }
}
#endif
