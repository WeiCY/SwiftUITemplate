import Foundation

/// 通用 Tab 标识。具体 Tab 枚举、标题和图标由宿主 App 定义。
public struct CYTabID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "CYTabID cannot be empty")
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}
