import Foundation

// MARK: - Optional 扩展
//
// 提供保留错误的解包、nil/空集合及空白字符串判定。
//
// 用法：
// ```swift
// let name: String? = nil
// name.isNilOrBlank         // true
// try name.orThrow(CYAppError.unknown("名称不能为空"))
// ```

extension Optional {
    
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
}

extension Optional where Wrapped == String {
    
    /// 是否为 nil 或空白字符串
    public var isNilOrBlank: Bool {
        guard let value = self else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
