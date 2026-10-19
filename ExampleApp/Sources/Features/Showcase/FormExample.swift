import SwiftUI
import Observation
import CYAppCore
import CYAppDesignSystem

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
            PrimaryButton(title: "提交 / Submit", action: submit, isLoading: model.isLoading)
            if let error = model.error {
                Text(error.message).foregroundStyle(.red)
                Button("重试 / Retry") { Task { await model.submit() } }
            }
            if model.submitted { Label("提交成功 / Submitted", systemImage: "checkmark.circle") }
        }
        .navigationTitle("表单 / Form")
    }

    private func submit() {
        focus = nil
        Task { await model.submit() }
    }
}
