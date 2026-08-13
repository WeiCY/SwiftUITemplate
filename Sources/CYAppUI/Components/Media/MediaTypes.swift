#if canImport(UIKit) && canImport(Photos)
import SwiftUI
import Photos

// MARK: - 媒体选择器数据模型
//
// 统一的媒体项封装，支持两种来源：
// - PHAsset（自定义网格选择器，支持选择状态保留）
// - UIImage（系统 PhotosPicker / 拍照，无 PHAsset）
//
// 调用方通过 `loadImage()` / `loadData()` 异步获取图片，无需关心来源差异。

// MARK: - 媒体类型

public enum CYMediaType: Sendable {
    case image
    case video
    case unknown
}

// MARK: - 选择器样式

/// 媒体选择器样式
public enum CYMediaPickerStyle: Sendable {
    /// 微信风格自定义网格选择器（推荐）
    /// - 支持选择状态保留、相册切换、原图选项
    case grid
    /// 系统原生 PhotosPicker（简单场景）
    /// - 轻量，但无法保留选择状态
    case system
}

// MARK: - 媒体来源（仅 .system 样式使用）

/// 媒体选择来源
public enum CYMediaSource: Sendable {
    case album
    case camera
    case both
}

/// 媒体类型过滤
public enum CYMediaFilter: Sendable {
    case images
    case videos
    case any
}

// MARK: - 媒体项

/// 统一的媒体项封装
///
/// 两种构造方式：
/// ```swift
/// // 网格选择器返回（基于 PHAsset）
/// let item = CYMediaItem(asset: asset)
///
/// // 系统选择器 / 拍照返回（基于 UIImage）
/// let item = CYMediaItem(image: image)
/// ```
@MainActor
public struct CYMediaItem: Identifiable, Hashable {
    public let id: String
    public let asset: PHAsset?
    public let image: UIImage?

    /// 基于 PHAsset 构造（网格选择器）
    public init(asset: PHAsset) {
        self.asset = asset
        self.image = nil
        self.id = asset.localIdentifier
    }

    /// 基于 UIImage 构造（系统选择器 / 拍照）
    public init(image: UIImage, id: String = UUID().uuidString) {
        self.asset = nil
        self.image = image
        self.id = id
    }

    public var mediaType: CYMediaType {
        if let asset {
            switch asset.mediaType {
            case .image: return .image
            case .video: return .video
            default: return .unknown
            }
        }
        return .image
    }

    public var isVideo: Bool { mediaType == .video }

    public var durationText: String? {
        guard let asset, asset.mediaType == .video else { return nil }
        let total = Int(asset.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 异步加载 UIImage
    public func loadImage() async -> UIImage? {
        if let image { return image }
        if let asset { return await CYPhotoAssetLoader.shared.loadFullImage(for: asset) }
        return nil
    }

    /// 异步加载图片 Data（用于上传）
    public func loadData() async -> Data? {
        if let asset { return await CYPhotoAssetLoader.shared.loadData(for: asset) }
        if let image { return image.jpegData(compressionQuality: 0.9) }
        return nil
    }
}

// MARK: - Array 扩展

@MainActor
public extension Array where Element == CYMediaItem {
    /// 提取所有 PHAsset localIdentifier（用于选择状态保留）
    var localIdentifiers: [String] {
        compactMap { $0.asset?.localIdentifier }
    }

    /// 批量异步加载 UIImage
    func loadImages() async -> [UIImage] {
        var images: [UIImage] = []
        for item in self {
            if let image = await item.loadImage() {
                images.append(image)
            }
        }
        return images
    }
}

// MARK: - 相册信息

@MainActor
public struct CYAlbumInfo: Identifiable {
    public let id: String
    public let title: String
    public let assetCollection: PHAssetCollection?
    public let coverAsset: PHAsset?
    public let count: Int

    /// 「所有照片」虚拟相册
    public static let allPhotos = CYAlbumInfo(
        id: "__all_photos__",
        title: "media_all_photos".cyLocalized,
        assetCollection: nil,
        coverAsset: nil,
        count: 0
    )
}
#endif
