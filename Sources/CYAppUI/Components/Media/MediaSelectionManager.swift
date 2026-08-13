#if canImport(UIKit) && canImport(Photos)
import SwiftUI
import Photos

// MARK: - 媒体选择状态管理器
//
// 核心职责：
// 1. 维护已选 PHAsset 列表（有序，记录选择顺序）
// 2. 支持选择/取消/切换，自动执行数量上限检查
// 3. 支持「保留上次记录」——调用方传入 preselected localIdentifiers，
//    Manager 负责加载并恢复选择状态
// 4. 支持原图选项开关
//
// 使用方式：
// ```swift
// let manager = CYMediaSelectionManager(maxSelection: 9)
// manager.toggle(asset)       // 选择/取消
// manager.isSelected(asset)   // 是否已选
// manager.selectionIndex(of: asset)  // 选择序号（用于显示 1,2,3...）
// ```

/// 媒体选择状态管理器
@MainActor
@Observable
public final class CYMediaSelectionManager {

    /// 已选媒体项（有序）
    public var selectedItems: [CYMediaItem] = []

    /// 最大选择数
    public let maxSelection: Int

    /// 是否允许选择原图
    public var allowsOriginal: Bool

    /// 是否发送原图
    public var sendOriginal: Bool = false

    public init(maxSelection: Int = 9, allowsOriginal: Bool = false) {
        self.maxSelection = max(1, maxSelection)
        self.allowsOriginal = allowsOriginal
    }

    // MARK: - 查询

    public var selectedCount: Int { selectedItems.count }
    public var hasSelection: Bool { !selectedItems.isEmpty }
    public var canSelectMore: Bool { selectedItems.count < maxSelection }
    public var remainingCapacity: Int { maxSelection - selectedItems.count }

    public func isSelected(_ asset: PHAsset) -> Bool {
        selectedItems.contains { $0.asset == asset }
    }

    public func selectionIndex(of asset: PHAsset) -> Int? {
        selectedItems.firstIndex { $0.asset == asset }
    }

    // MARK: - 操作

    /// 切换选择状态，返回是否操作成功
    @discardableResult
    public func toggle(_ asset: PHAsset) -> Bool {
        if let index = selectionIndex(of: asset) {
            selectedItems.remove(at: index)
            return true
        }
        return select(asset)
    }

    /// 选择指定 PHAsset，返回是否成功（已达上限时返回 false）
    @discardableResult
    public func select(_ asset: PHAsset) -> Bool {
        guard !isSelected(asset), canSelectMore else { return false }
        selectedItems.append(CYMediaItem(asset: asset))
        return true
    }

    /// 取消选择
    public func deselect(_ asset: PHAsset) {
        selectedItems.removeAll { $0.asset == asset }
    }

    /// 移除指定位置的已选项
    public func remove(at index: Int) {
        guard selectedItems.indices.contains(index) else { return }
        selectedItems.remove(at: index)
    }

    /// 清空所有选择
    public func clear() {
        selectedItems.removeAll()
    }

    // MARK: - 状态恢复

    /// 从 localIdentifiers 恢复选择状态（「保留上次记录」）
    public func restore(from identifiers: [String]) {
        // 外部绑定是权威状态：即使为空，也必须清空当前选择。
        clear()
        guard !identifiers.isEmpty else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        // 按传入顺序排序，保持上次选择的顺序
        let ordered = identifiers.compactMap { id in
            assets.first { $0.localIdentifier == id }
        }
        for asset in ordered where canSelectMore {
            select(asset)
        }
    }

    // MARK: - 拍照后自动选中

    /// 拍照后，将 UIImage 直接添加为已选项（无 PHAsset）
    @discardableResult
    public func addCapturedImage(_ image: UIImage) -> Bool {
        guard canSelectMore else { return false }
        selectedItems.append(CYMediaItem(image: image))
        return true
    }
}
#endif
