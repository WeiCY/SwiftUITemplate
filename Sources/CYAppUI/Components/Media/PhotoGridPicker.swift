#if canImport(UIKit) && canImport(Photos)
import SwiftUI
import Photos
import CYAppDesignSystem

// MARK: - 微信风格图片网格选择器
//
// 仿微信选择逻辑：
// - 4 列网格，拍照按钮在左上角第一位
// - 点击缩略图 → 全屏预览
// - 点击右下角圆形徽标 → 选中/取消（带序号 1,2,3...）
// - 达到上限时未选徽标变灰
// - 支持相册切换（下拉面板）

// MARK: - 主网格视图

struct CYPhotoGridPicker: View {

    let selectionManager: CYMediaSelectionManager
    let filter: CYMediaFilter
    let allowsCamera: Bool
    let assets: [PHAsset]
    let onCamera: () -> Void
    let onPreview: (Int) -> Void
    let onMaxReached: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 4)
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let spacing: CGFloat = 2

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                if allowsCamera {
                    cameraCell
                }
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    CYPhotoGridCell(
                        asset: asset,
                        selectionManager: selectionManager,
                        thumbnailSize: thumbnailSize,
                        onToggle: {
                            if !selectionManager.toggle(asset) {
                                onMaxReached()
                            }
                        },
                        onTap: {
                            onPreview(index)
                        }
                    )
                }
            }
            .padding(.horizontal, spacing)
            .padding(.bottom, 80)
        }
        .overlay {
            if assets.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - 拍照按钮

    private var cameraCell: some View {
        Button(action: onCamera) {
            ZStack {
                CYAppColor.secondaryBackground
                Image(systemName: "camera")
                    .font(.system(size: 28))
                    .foregroundStyle(CYAppColor.textSecondary)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
        }
        .buttonStyle(CYScaledButtonStyle())
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: CYAppDimens.marginS) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(CYAppColor.textTertiary)
            Text("media_no_photos".cyLocalized)
                .font(CYAppFont.bodyMedium)
                .foregroundStyle(CYAppColor.textSecondary)
        }
    }

}

// MARK: - 网格单元

struct CYPhotoGridCell: View {

    let asset: PHAsset
    let selectionManager: CYMediaSelectionManager
    let thumbnailSize: CGSize
    let onToggle: () -> Void
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    private var isSelected: Bool { selectionManager.isSelected(asset) }
    private var selectionIndex: Int? { selectionManager.selectionIndex(of: asset) }
    private var canSelectMore: Bool { selectionManager.canSelectMore }
    private let selectionHitSize: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                // 缩略图固定填充方形单元，原始宽高比不会影响网格布局
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        CYAppColor.secondaryBackground
                            .overlay(ProgressView().controlSize(.small))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .contentShape(Rectangle())

                // 已选遮罩
                if isSelected {
                    Color.black.opacity(0.25)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .allowsHitTesting(false)
                }

                // 视频时长
                if asset.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 10))
                            if let duration = CYMediaItem(asset: asset).durationText {
                                Text(duration)
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(4)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    .allowsHitTesting(false)
                }

                // 选择徽标
                CYSelectionBadge(
                    isSelected: isSelected,
                    index: selectionIndex,
                    enabled: canSelectMore || isSelected
                )
                .padding(6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let isSelectionTap = value.location.x >= proxy.size.width - selectionHitSize
                        && value.location.y >= proxy.size.height - selectionHitSize
                    if isSelectionTap {
                        onToggle()
                    } else {
                        onTap()
                    }
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: asset.localIdentifier) {
            thumbnail = await CYPhotoAssetLoader.shared.loadThumbnail(
                for: asset, targetSize: thumbnailSize
            )
        }
    }
}

// MARK: - 选择徽标

struct CYSelectionBadge: View {

    let isSelected: Bool
    let index: Int?
    let enabled: Bool

    private let size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 1.5)
                .background(
                    Circle().fill(isSelected ? CYAppColor.primary : .clear)
                )
                .frame(width: size, height: size)

            if isSelected, let index {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .opacity(enabled ? 1.0 : 0.35)
    }
}

// MARK: - 相册列表面板

struct CYAlbumListSheet: View {

    let albums: [CYAlbumInfo]
    @Binding var selectedAlbum: CYAlbumInfo
    let onSelect: (CYAlbumInfo) -> Void

    var body: some View {
        List(albums) { album in
            Button {
                selectedAlbum = album
                onSelect(album)
            } label: {
                HStack(spacing: 12) {
                    // 相册封面
                    Group {
                        if let cover = album.coverAsset {
                            CYAlbumCoverThumbnail(asset: cover)
                        } else {
                            RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                                .fill(CYAppColor.secondaryBackground)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipped()
                    .cornerRadius(CYAppDimens.radiusM)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(CYAppFont.bodyMedium)
                            .foregroundStyle(CYAppColor.textPrimary)
                        Text("\(album.count)")
                            .font(CYAppFont.caption)
                            .foregroundStyle(CYAppColor.textSecondary)
                    }

                    Spacer()

                    if selectedAlbum.id == album.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(CYAppColor.primary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - 相册封面缩略图

struct CYAlbumCoverThumbnail: View {

    let asset: PHAsset
    @State private var image: UIImage?
    private let size = CGSize(width: 144, height: 144)

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                CYAppColor.secondaryBackground
            }
        }
        .task(id: asset.localIdentifier) {
            image = await CYPhotoAssetLoader.shared.loadThumbnail(
                for: asset, targetSize: size
            )
        }
    }
}
#endif
