import SwiftUI
import Observation
import CYAppCore
import CYAppDesignSystem
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class FormExampleModel: CYBaseViewModel {
    var email = ""
    var password = ""
    var confirmation = ""
    var simulateFailure = false
    var submitted = false
    var validates = false
    private let submitAction: () async throws -> Void

    init(submit: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(400)) }) {
        submitAction = submit
        super.init()
    }

    var emailError: String? { CYFormField(name: "Email").required().email().validate(email) }
    var passwordError: String? { CYFormField(name: "Password").required().minLength(8).validate(password) }
    var confirmationError: String? { password == confirmation ? nil : "两次密码不一致 / Passwords differ" }

    func submit() async {
        guard !isLoading else { return }
        validates = true
        submitted = false
        guard emailError == nil, passwordError == nil, confirmationError == nil else { return }
        await executeTask { [weak self] in
            guard let self else { return }
            try await self.submitAction()
            if self.simulateFailure { throw CYAppError.network("模拟提交失败 / Simulated failure") }
            self.submitted = true
        }
    }
}

struct FormExample: View {
    enum Field: Hashable { case email, password, confirmation }
    @State private var model = FormExampleModel()
    @FocusState private var focus: Field?

    var body: some View {
        Form {
            CYTextField(title: "Email", placeholder: "name@example.com", text: $model.email,
                        error: model.validates ? model.emailError : nil, submitLabel: .next,
                        autocorrectionDisabled: true, onSubmit: { focus = .password })
                .focused($focus, equals: .email)
            CYTextField(title: "Password", placeholder: "至少 8 个字符 / 8 characters", text: $model.password,
                        isSecure: true, error: model.validates ? model.passwordError : nil,
                        submitLabel: .next, onSubmit: { focus = .confirmation })
                .focused($focus, equals: .password)
            CYTextField(title: "Confirm", placeholder: "再次输入 / Repeat", text: $model.confirmation,
                        isSecure: true, error: model.validates ? model.confirmationError : nil,
                        submitLabel: .done, onSubmit: submit)
                .focused($focus, equals: .confirmation)
            Toggle("模拟失败 / Fail submission", isOn: $model.simulateFailure)
            if let error = model.error {
                Text(error.message).foregroundStyle(.red)
                Button("重试 / Retry") { Task { await model.submit() } }
            }
            if model.submitted { Label("提交成功 / Submitted", systemImage: "checkmark.circle") }
        }
        .navigationTitle("表单 / Form")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CYBottomActionBar {
                if focus != nil {
                    Button("收起键盘 / Done") { focus = nil }.accessibilityIdentifier("form.keyboardDone")
                }
            } trailing: {
                PrimaryButton(title: "提交 / Submit", action: submit, isLoading: model.isLoading)
                    .accessibilityIdentifier("form.submit")
            }
        }
    }

    private func submit() {
        focus = nil
        Task { await model.submit() }
    }
}

/// A focus/normalization recipe; completion only moves focus, never performs authentication.
struct VerificationCodeExample: View {
    private enum Field: String, Hashable { case code, next }
    @State private var code = ProcessInfo.processInfo.arguments.contains("--otp-long")
        ? "123456781234567812345678" : (ProcessInfo.processInfo.arguments.contains("--otp-prefill") ? "12a٣3456z7" : "")
    @State private var next = ""
    @State private var completions = 0
    @State private var disabled = false
    @State private var longCode = ProcessInfo.processInfo.arguments.contains("--otp-long")
    @FocusState private var focus: Field?

    private var layoutCheck: Bool { ProcessInfo.processInfo.arguments.contains("--otp-layout") }

    var body: some View {
        Form {
            Section {
                CYVerificationCodeInput(code: $code, length: longCode ? 24 : 6, title: "OTP", isDisabled: disabled) { _ in
                    completions += 1
                    focus = .next
                }
                .focused($focus, equals: .code)
                .frame(maxWidth: layoutCheck ? 240 : .infinity)
                TextField("Next field", text: $next)
                    .focused($focus, equals: .next)
                    .submitLabel(.done)
                    .onSubmit { focus = nil }
                Text("Code: \(code)").accessibilityIdentifier("otp.value")
                Text("Callbacks: \(completions)").accessibilityIdentifier("otp.callbacks")
                Text("Focus: \(focus?.rawValue ?? "none")").accessibilityIdentifier("otp.focus")
            }
            Section {
                Button("外部更新 / External update") { code = "9a８8 7654321" }
                    .accessibilityIdentifier("otp.external")
                Button("清空 / Clear") { code = "" }.accessibilityIdentifier("otp.clear")
                Button("聚焦 / Focus code") { focus = .code }.accessibilityIdentifier("otp.focusCode")
                Toggle("禁用 / Disabled", isOn: $disabled).accessibilityIdentifier("otp.disabled")
                Toggle("24 位 / Long code", isOn: $longCode).accessibilityIdentifier("otp.long")
            }
        }
        .navigationTitle("验证码 / Code")
        .scrollDismissesKeyboard(.interactively)
        .dynamicTypeSize(layoutCheck ? .accessibility5 : .large)
        .task {
            #if canImport(UIKit)
            if ProcessInfo.processInfo.arguments.contains("--otp-paste") { UIPasteboard.general.string = "a12-3 ٤456xyz789" }
            #endif
            if !layoutCheck { focus = .code }
        }
        #if canImport(UIKit)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘 / Done") { focus = nil }.accessibilityIdentifier("otp.keyboardDone")
            }
        }
        #endif
    }
}
