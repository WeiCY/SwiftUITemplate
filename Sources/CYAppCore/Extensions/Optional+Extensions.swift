import Foundation

// MARK: - Optional 扩展
//
// 提供 Optional 的安全解包、判空、链式操作等便捷方法。
//
// 用法：
// ```swift
// let name: String? = nil
// name.or("默认值")         // "默认值"
// name.isNilOrBlank         // true
// name.then { print($0) }  // nil 时不执行
// try name.orThrow(CYAppError.unknown("名称不能为空"))
// ```

extension Optional {
    
    /// 返回包装值或默认值
    /// 用法: optional.or("default")
    public func or(_ default: Wrapped) -> Wrapped {
        return self ?? `default`
    }
    
    /// 是否为 nil
    public var isNil: Bool {
        return self == nil
    }
    
    /// 是否非 nil
    public var isNotNil: Bool {
        return self != nil
    }
    
    /// 非 nil 时执行闭包
    /// 用法: optional.then { print($0) }
    public func then(_ closure: (Wrapped) -> Void) {
        if let value = self {
            closure(value)
        }
    }
    
    /// 为 nil 时抛出错误
    /// 用法: let value = try optional.orThrow(CYAppError.unknown("值为空"))
    public func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}

extension Optional where Wrapped: Collection {
    
    /// 是否为 nil 或集合为空
    public var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
    
    /// 返回集合的 count，nil 时返回 0
    public var countOrZero: Int {
        return self?.count ?? 0
    }
}

extension Optional where Wrapped == String {
    
    /// 是否为 nil 或空白字符串
    public var isNilOrBlank: Bool {
        guard let value = self else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Optional where Wrapped: Numeric {
    
    /// 返回包装值或 0
    public var orZero: Wrapped {
        return self ?? 0
    }
}
