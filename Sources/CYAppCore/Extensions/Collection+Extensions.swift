import Foundation

// MARK: - Collection / Array / Sequence 扩展
//
// 提供安全索引、去重、分组、分块、集合运算等常用操作。
//
// 用法：
// ```swift
// let arr = [1, 2, 2, 3, 4, 4, 5]
// arr[safe: 10]              // nil（安全索引）
// arr.unique()               // [1, 2, 3, 4, 5]
// arr.chunked(into: 2)       // [[1,2],[2,3],[4,4],[5]]
// arr.sorted(by: \.self)     // 按 KeyPath 排序
// users.grouped(by: \.role)  // 按属性分组为字典
// ```

extension Collection {
    
    /// 安全索引访问，越界返回 nil 而非崩溃
    public subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// 是否非空
    public var isNotEmpty: Bool {
        return !isEmpty
    }
    
    /// 元素数量（count 的别名）
    public var length: Int {
        return count
    }
}

// MARK: - Array 扩展 扩展

extension Array {
    
    /// 按 KeyPath 去重，保持原始顺序
    /// 用法: users.unique(by: \.id)
    public func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
    
    /// 按条件拆分为两个数组
    /// 用法: let (even, odd) = numbers.divided { $0.isMultiple(of: 2) }
    public func divided(by condition: (Element) -> Bool) -> (matching: [Element], nonMatching: [Element]) {
        var matching = [Element]()
        var nonMatching = [Element]()
        for element in self {
            if condition(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        return (matching, nonMatching)
    }
    
    /// 按指定大小分块
    /// 用法: [1,2,3,4,5].chunked(into: 2) → [[1,2],[3,4],[5]]
    public func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    /// 随机取样 n 个元素
    public func sample(_ n: Int) -> [Element] {
        return Array(shuffled().prefix(n))
    }
    
    /// 安全移除首个元素（空数组不崩溃）
    @discardableResult
    public mutating func removeFirstSafe() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
    
    /// 安全移除末尾元素（空数组不崩溃）
    @discardableResult
    public mutating func removeLastSafe() -> Element? {
        guard !isEmpty else { return nil }
        return removeLast()
    }
}

extension Array where Element: Hashable {
    
    /// 去重并保持原始顺序
    /// 用法: [1,2,2,3].unique() → [1,2,3]
    public func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
    
    /// 取交集（两个数组中都有的元素）
    public func intersection(_ other: [Element]) -> [Element] {
        let set = Set(other)
        return filter { set.contains($0) }
    }
    
    /// 取并集（去重合并）
    public func union(_ other: [Element]) -> [Element] {
        return (self + other).unique()
    }
    
    /// 取差集（在 self 中但不在 other 中的元素）
    public func difference(_ other: [Element]) -> [Element] {
        let set = Set(other)
        return filter { !set.contains($0) }
    }
}

// MARK: - Sequence 扩展 扩展

extension Sequence {
    
    /// 按 KeyPath 分组为字典
    /// 用法: users.grouped(by: \.role)
    public func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self) { $0[keyPath: keyPath] }
    }
    
    /// 按 KeyPath 升序排序
    /// 用法: users.sorted(by: \.name)
    public func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }
    
    /// 按 KeyPath 降序排序
    public func sortedDescending<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { $0[keyPath: keyPath] > $1[keyPath: keyPath] }
    }
    
    /// 统计满足条件的元素数量
    public func count(where condition: (Element) -> Bool) -> Int {
        return filter(condition).count
    }
}
