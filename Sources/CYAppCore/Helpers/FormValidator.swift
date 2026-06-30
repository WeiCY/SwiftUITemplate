import Foundation

// MARK: - 表单验证框架
//
// 声明式表单验证，支持：
// - 单字段多条规则链式组合
// - 实时验证（计算属性自动刷新）
// - 提交时统一验证所有字段
// - 自定义验证规则
//
// ## 基本用法
// ```swift
// // 1. 定义字段
// let email = CYFormField(name: "邮箱")
//     .required()
//     .email()
//
// let password = CYFormField(name: "密码")
//     .required()
//     .minLength(8)
//
// // 2. 创建验证器
// let validator = CYFormValidator(fields: [email, password])
//
// // 3. 绑定到 ViewModel
// @Observable
// class LoginViewModel {
//     var email = ""
//     var password = ""
//
//     private let emailField = CYFormField(name: "邮箱").required().email()
//     private let passwordField = CYFormField(name: "密码").required().minLength(8)
//
//     var emailError: String? { emailField.validate(email) }
//     var passwordError: String? { passwordField.validate(password) }
//     var isValid: Bool { emailError == nil && passwordError == nil }
//
//     func submit() async {
//         guard isValid else { return }
//         // 提交逻辑...
//     }
// }
// ```
//
// ## SwiftUI 中使用
// ```swift
// struct LoginView: View {
//     @State private var vm = LoginViewModel()
//
//     var body: some View {
//         Form {
//             TextField("邮箱", text: $vm.email)
//             if let error = vm.emailError {
//                 Text(error).font(.caption).foregroundStyle(.red)
//             }
//
//             SecureField("密码", text: $vm.password)
//             if let error = vm.passwordError {
//                 Text(error).font(.caption).foregroundStyle(.red)
//             }
//
//             Button("登录") { Task { await vm.submit() } }
//                 .disabled(!vm.isValid)
//         }
//     }
// }
// ```

// MARK: - 验证规则

/// 单条验证规则
public struct CYValidationRule: Sendable {
    /// 验证失败时的错误信息
    public let message: String
    /// 验证逻辑（返回 true 表示通过）
    public let validate: @Sendable (String) -> Bool
    
    public init(message: String, validate: @escaping @Sendable (String) -> Bool) {
        self.message = message
        self.validate = validate
    }
}

// MARK: - 表单字段

/// 表单字段验证器 — 链式组合多条验证规则
///
/// ```swift
/// let field = CYFormField(name: "用户名")
///     .required()
///     .minLength(3)
///     .maxLength(20)
/// ```
public struct CYFormField: Sendable {
    
    public let name: String
    private var rules: [CYValidationRule] = []
    
    public init(name: String) {
        self.name = name
    }
    
    // MARK: - 验证执行
    
    /// 验证字段值
    /// - Parameter value: 当前字段值
    /// - Returns: 第一条失败的错误信息，全部通过返回 nil
    public func validate(_ value: String) -> String? {
        for rule in rules {
            if !rule.validate(value) {
                return rule.message
            }
        }
        return nil
    }
    
    /// 字段是否有效（无错误）
    public func isValid(_ value: String) -> Bool {
        validate(value) == nil
    }
    
    // MARK: - 链式规则添加
    
    /// 添加自定义验证规则
    public func rule(_ message: String, _ check: @escaping @Sendable (String) -> Bool) -> CYFormField {
        var field = self
        field.rules.append(CYValidationRule(message: message, validate: check))
        return field
    }
    
    // MARK: - 内置规则
    
    /// 不能为空
    public func required(message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)不能为空") { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    /// 最小长度
    public func minLength(_ length: Int, message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)至少\(length)个字符") { $0.count >= length }
    }
    
    /// 最大长度
    public func maxLength(_ length: Int, message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)最多\(length)个字符") { $0.count <= length }
    }
    
    /// 邮箱格式
    public func email(message: String? = nil) -> CYFormField {
        rule(message ?? "邮箱格式不正确") { $0.isValidEmail }
    }
    
    /// 手机号格式
    public func phone(message: String? = nil) -> CYFormField {
        rule(message ?? "手机号格式不正确") { $0.isValidPhoneNumber }
    }
    
    /// 必须包含数字
    public func containsDigit(message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)必须包含数字") { $0.contains(where: { $0.isNumber }) }
    }
    
    /// 必须包含字母
    public func containsLetter(message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)必须包含字母") { $0.contains(where: { $0.isLetter }) }
    }
    
    /// 必须包含大写字母
    public func containsUppercase(message: String? = nil) -> CYFormField {
        rule(message ?? "\(name)必须包含大写字母") { $0.contains(where: { $0.isUppercase }) }
    }
    
    /// 正则匹配
    public func regex(_ pattern: String, message: String) -> CYFormField {
        rule(message) { $0.matches(pattern: pattern) }
    }
    
    /// 与另一个字段值一致（确认密码场景）
    public func match(_ other: String, message: String? = nil) -> CYFormField {
        rule(message ?? "两次输入不一致") { $0 == other }
    }
}

// MARK: - 表单验证器

/// 多字段表单验证器
///
/// ```swift
/// let validator = CYFormValidator([
///     .init(key: "email", field: CYFormField(name: "邮箱").required().email()),
///     .init(key: "password", field: CYFormField(name: "密码").required().minLength(8)),
/// ])
///
/// let errors = validator.validateAll(["email": email, "password": password])
/// // errors = ["email": "邮箱不能为空", "password": nil]
/// ```
public struct CYFormValidator: Sendable {
    
    /// 字段注册项
    public struct Entry: Sendable {
        public let key: String
        public let field: CYFormField
        
        public init(key: String, field: CYFormField) {
            self.key = key
            self.field = field
        }
    }
    
    private let entries: [Entry]
    
    public init(_ entries: [Entry]) {
        self.entries = entries
    }
    
    /// 验证所有字段
    /// - Parameter values: key → value 映射
    /// - Returns: key → errorMessage? 映射（nil 表示通过）
    public func validateAll(_ values: [String: String]) -> [String: String?] {
        var results: [String: String?] = [:]
        for entry in entries {
            let value = values[entry.key] ?? ""
            results[entry.key] = entry.field.validate(value)
        }
        return results
    }
    
    /// 是否所有字段都通过验证
    public func isAllValid(_ values: [String: String]) -> Bool {
        entries.allSatisfy { entry in
            let value = values[entry.key] ?? ""
            return entry.field.isValid(value)
        }
    }
    
    /// 获取第一个验证失败的字段信息
    public func firstError(_ values: [String: String]) -> (key: String, message: String)? {
        for entry in entries {
            let value = values[entry.key] ?? ""
            if let error = entry.field.validate(value) {
                return (entry.key, error)
            }
        }
        return nil
    }
}
