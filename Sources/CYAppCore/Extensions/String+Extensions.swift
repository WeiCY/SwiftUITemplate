import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - String 扩展
//
// 提供字符串的验证、转换、编码、哈希等常用操作。
//
// 用法：
// ```swift
// "test@email.com".isValidEmail    // true
// "13800138000".isValidPhoneNumber // true
// "Hello World".truncated(to: 5)   // "Hello..."
// "helloWorld".camelCaseToSnakeCase // "hello_world"
// "hello".copyToClipboard()        // 复制到剪贴板
// "password".md5                   // MD5 哈希
// ```

extension String {
    
    // MARK: - 验证
    
    /// 简单 ASCII 邮箱形状检查；不覆盖国际化邮箱，也不验证地址可达性。
    public var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    /// 是否为合法的中国手机号格式
    public var isValidPhoneNumber: Bool {
        let phoneRegEx = "^1[3-9]\\d{9}$"
        let phonePred = NSPredicate(format: "SELF MATCHES %@", phoneRegEx)
        return phonePred.evaluate(with: self)
    }
    
    /// 兼容的域名式网页地址正则；并非通用 URL 校验，不能用于允许列表或安全决策。
    public var isValidURL: Bool {
        let urlRegEx = "^(https?://)?([\\w-]+\\.)+[\\w-]+(/[\\w-./?%&=]*)?$"
        let urlPred = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
        return urlPred.evaluate(with: self)
    }
    
    /// 是否匹配指定的正则表达式
    public func matches(pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 中国大陆居民身份证号的形状检查；不验证校验位、真实日期或身份。
    public var isValidIDCard: Bool {
        let idCardRegEx = "^[1-9]\\d{5}(18|19|20)\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx]$"
        return NSPredicate(format: "SELF MATCHES %@", idCardRegEx).evaluate(with: self)
    }
    
    // MARK: - 检查
    
    /// 是否非空白（不为空且去除首尾空格后不为空）
    public var isNotBlank: Bool {
        return !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 是否全部由 Unicode 数字 Character 组成（包括非 ASCII 数字）；不是十进制数解析。
    public var isNumeric: Bool {
        return !isEmpty && allSatisfy { $0.isNumber }
    }
    
    /// 是否全为字母
    public var isAlphabetic: Bool {
        return !isEmpty && allSatisfy { $0.isLetter }
    }
    
    /// 是否全为字母或数字
    public var isAlphanumeric: Bool {
        return !isEmpty && allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    // MARK: - 本地化
    
    /// 本地化字符串（支持运行时多语言切换）
    ///
    /// 读取 CYLocalizationManager 当前语言的本地化资源。
    /// 用法: "key_name".localized
    public var localized: String {
        return CYLocalizationManager.shared.localized(self)
    }
    
    /// 带参数的本地化字符串
    /// 用法: "greeting".localized(with: "John")
    public func localized(with arguments: CVarArg...) -> String {
        return String(format: CYLocalizationManager.shared.localized(self), arguments: arguments)
    }
    
    /// 使用系统 NSLocalizedString（忽略运行时语言切换）
    ///
    /// 适用于始终跟随系统语言的场景。
    public var systemLocalized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    // MARK: - 转换
    
    /// 首字母大写，其余不变
    public var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
    
    /// 驼峰转下划线（camelCase → snake_case）
    public var camelCaseToSnakeCase: String {
        let pattern = "([a-z])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(startIndex..., in: self)
        return regex?.stringByReplacingMatches(in: self, range: range, withTemplate: "$1_$2")
            .lowercased() ?? self
    }
    
    /// 下划线转驼峰（snake_case → camelCase）
    public var snakeCaseToCamelCase: String {
        let components = split(separator: "_")
        guard let first = components.first else { return self }
        return String(first).lowercased() + components.dropFirst()
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
    }
    
    /// 截断到指定字符数并添加后缀；长度 <= 0 返回空字符串（不追加后缀）。
    /// 用法: "Hello World".truncated(to: 5) → "Hello..."
    public func truncated(to length: Int, suffix: String = "...") -> String {
        guard length > 0 else { return "" }
        guard count > length else { return self }
        return String(prefix(length)) + suffix
    }
    
    /// 去除首尾空白和换行符
    public var stripped: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 以正则移除形如 <...> 的文本；不解析 HTML、不解码实体，不用于内容消毒。
    public var strippedHTML: String {
        return replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    // MARK: - 编码 / 哈希
    
    /// Base64 编码
    public var base64Encoded: String? {
        return data(using: .utf8)?.base64EncodedString()
    }
    
    /// Base64 解码
    public var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// URL 编码（百分号转义）。
    ///
    /// 在 `.urlQueryAllowed` 基础上额外转义 `& = + ? /`，避免作为 query 值时
    /// 破坏参数结构（如值中包含 `&` 会被误解析为下一个参数）。
    public var urlEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
    
    /// URL 解码（百分号反转义）
    public var urlDecoded: String {
        return removingPercentEncoding ?? self
    }
    
    /// 返回 MD5 摘要，仅用于兼容指纹，不用于密码或安全签名。
    public var md5: String {
        guard let data = data(using: .utf8) else { return self }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 剪贴板
    
    #if canImport(UIKit)
    /// 复制字符串到系统剪贴板
    public func copyToClipboard() {
        UIPasteboard.general.string = self
    }
    #endif
    
    // MARK: - 类型转换
    
    /// 转换为 URL（如格式合法）
    public var asURL: URL? {
        return URL(string: self)
    }
    
    /// 转换为 UTF-8 Data
    public var asData: Data? {
        return data(using: .utf8)
    }
    
    /// 转换为 Double（如可能）
    public var toDouble: Double? {
        return Double(self)
    }
    
    /// 转换为 Int（如可能）
    public var toInt: Int? {
        return Int(self)
    }
}
