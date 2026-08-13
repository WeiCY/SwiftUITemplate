#if canImport(UIKit) && canImport(Photos)
import UIKit
import Photos

// MARK: - PHAsset 图片加载器
//
// 封装 PHImageManager，提供缩略图、原图、Data 三种加载方式。
// 内置 NSCache 缓存缩略图，避免重复请求。
//
// Photos / UIKit 的对象只在 SwiftUI 的主 Actor 域内访问，避免跨 Actor
// 传递非 Sendable 的 PHAsset、UIImage 和 Photos framework 对象。

/// PHAsset 图片加载器（单例）
@MainActor
public final class CYPhotoAssetLoader {

    public static let shared = CYPhotoAssetLoader()

    private let imageManager = PHImageManager.default()
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        thumbnailCache.countLimit = 300
    }

    // MARK: - 缩略图

    /// 加载缩略图（带缓存，适用于网格）
    public func loadThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 200, height: 200)
    ) async -> UIImage? {
        let cacheKey = "\(asset.localIdentifier)_\(Int(targetSize.width))" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        if let image {
            thumbnailCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    // MARK: - 原图

    /// 加载全尺寸图片（适用于预览）
    public func loadFullImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - 图片 Data

    /// 加载图片 Data（适用于上传）
    public func loadData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    // MARK: - 缓存管理

    /// 清除缩略图缓存
    public func clearCache() {
        thumbnailCache.removeAllObjects()
    }
}

// MARK: - 相册加载

public extension CYPhotoAssetLoader {

    /// 获取所有相册列表
    func fetchAlbums(filter: CYMediaFilter) async -> [CYAlbumInfo] {
        var albums: [CYAlbumInfo] = [.allPhotos]

        // 「所有照片」的 count 和 coverAsset
        let allFetchOptions = fetchOptions(for: filter)
        let allResult = PHAsset.fetchAssets(with: allFetchOptions)
        if allResult.count > 0 {
            albums[0] = CYAlbumInfo(
                id: "__all_photos__",
                title: "media_all_photos".cyLocalized,
                assetCollection: nil,
                coverAsset: allResult.lastObject,
                count: allResult.count
            )
        }

        // 用户相册
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)

        for fetchResult in [smartAlbums, userAlbums] {
            fetchResult.enumerateObjects { collection, _, _ in
                let opts = PHFetchOptions()
                opts.fetchLimit = 1
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                self.applyFilter(filter, to: opts)

                let assets = PHAsset.fetchAssets(in: collection, options: opts)
                guard assets.count > 0 else { return }

                // 获取实际 count（不带 fetchLimit）
                let countOpts = PHFetchOptions()
                self.applyFilter(filter, to: countOpts)
                let totalCount = PHAsset.fetchAssets(in: collection, options: countOpts).count

                albums.append(CYAlbumInfo(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "",
                    assetCollection: collection,
                    coverAsset: assets.firstObject,
                    count: totalCount
                ))
            }
        }

        return albums
    }

    /// 获取相册中的所有 PHAsset
    func fetchAssets(in album: CYAlbumInfo?, filter: CYMediaFilter) -> [PHAsset] {
        let options = fetchOptions(for: filter)
        let result: PHFetchResult<PHAsset>

        if let album, let collection = album.assetCollection {
            result = PHAsset.fetchAssets(in: collection, options: options)
        } else {
            result = PHAsset.fetchAssets(with: options)
        }

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: - Private

    private func fetchOptions(for filter: CYMediaFilter) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        applyFilter(filter, to: options)
        return options
    }

    private func applyFilter(_ filter: CYMediaFilter, to options: PHFetchOptions) {
        switch filter {
        case .images:
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        case .videos:
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .any:
            break
        }
    }
}
#endif
