import SwiftUI
import CYAppCore

#if canImport(UIKit)
import UIKit
#endif

// MARK: - 文本输入框

/// 标准文本输入框。
///
/// 内置标题、图标、错误提示和深色模式适配。
/// 支持提交回调、返回键样式、自动纠错开关与清除按钮；iOS 上还可指定键盘/内容类型。
public struct CYTextField: View {
    let title: String?
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    let error: String?
    let isDisabled: Bool
    let submitLabel: SubmitLabel?
    let autocorrectionDisabled: Bool
    let showsClearButton: Bool
    let onSubmit: (() -> Void)?

    #if canImport(UIKit)
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var textInputAutocapitalization: TextInputAutocapitalization?
    #endif

    @Binding var text: String

    public init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        error: String? = nil,
        isDisabled: Bool = false,
        submitLabel: SubmitLabel? = nil,
        autocorrectionDisabled: Bool = false,
        showsClearButton: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.error = error
        self.isDisabled = isDisabled
        self.submitLabel = submitLabel
        self.autocorrectionDisabled = autocorrectionDisabled
        self.showsClearButton = showsClearButton
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYAppDimens.marginS) {
            if let title {
                Text(title)
                    .font(CYAppFont.bodyMedium)
                    .foregroundStyle(CYAppColor.textPrimary)
            }

            HStack(spacing: CYAppDimens.marginS) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(CYAppColor.textSecondary)
                }

                field
                    .padding(.vertical, CYAppDimens.marginM)

                if showsClearButton, !text.isEmpty, !isDisabled {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CYAppColor.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("clear".cyLocalized)
                }
            }
            .padding(.horizontal, CYAppDimens.marginM)
            .frame(minHeight: CYAppDimens.inputHeight)
            .background(
                RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                    .stroke(
                        error != nil ? CYAppColor.error : CYAppColor.border,
                        lineWidth: CYAppDimens.borderWidth
                    )
            )
            .background(CYAppColor.background)
            .clipShape(.rect(cornerRadius: CYAppDimens.radiusM))

            if let error {
                Text(error)
                    .font(CYAppFont.caption)
                    .foregroundStyle(CYAppColor.error)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(CYAppFont.bodyMedium)
        .foregroundStyle(CYAppColor.textPrimary)
        .disabled(isDisabled)
        .submitLabelIfPresent(submitLabel)
        .autocorrectionDisabled(autocorrectionDisabled)
        .onSubmit { onSubmit?() }

        #if canImport(UIKit)
        base
            .textInputAutocapitalization(textInputAutocapitalization)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
        #else
        base
        #endif
    }
}

#if canImport(UIKit)
public extension CYTextField {
    /// iOS 专属初始化：可指定键盘类型、内容类型与大小写策略。
    init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        error: String? = nil,
        isDisabled: Bool = false,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType? = nil,
        textInputAutocapitalization: TextInputAutocapitalization? = nil,
        submitLabel: SubmitLabel? = nil,
        autocorrectionDisabled: Bool = false,
        showsClearButton: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            placeholder: placeholder,
            text: text,
            icon: icon,
            isSecure: isSecure,
            error: error,
            isDisabled: isDisabled,
            submitLabel: submitLabel,
            autocorrectionDisabled: autocorrectionDisabled,
            showsClearButton: showsClearButton,
            onSubmit: onSubmit
        )
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.textInputAutocapitalization = textInputAutocapitalization
    }
}
#endif

// MARK: - 可选修饰符辅助

private extension View {
    @ViewBuilder
    func submitLabelIfPresent(_ label: SubmitLabel?) -> some View {
        if let label {
            submitLabel(label)
        } else {
            self
        }
    }
}

// MARK: - 搜索框

/// 标准搜索框。
public struct CYSearchBar: View {
    let placeholder: String
    let showsCancelButton: Bool
    let onSearch: (() -> Void)?
    let onCancel: (() -> Void)?

    @Binding var text: String

    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        showsCancelButton: Bool = true,
        onSearch: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.showsCancelButton = showsCancelButton
        self.onSearch = onSearch
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: CYAppDimens.marginS) {
            HStack(spacing: CYAppDimens.marginS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(CYAppColor.textSecondary)

                TextField(placeholder, text: $text)
                    .font(CYAppFont.bodyMedium)
                    .foregroundStyle(CYAppColor.textPrimary)
                    .submitLabel(.search)
                    .onSubmit { onSearch?() }
                    .padding(.vertical, CYAppDimens.marginS)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CYAppColor.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("clear".cyLocalized)
                }
            }
            .padding(.horizontal, CYAppDimens.marginS)
            .frame(minHeight: 44)
            .background(CYAppColor.secondaryBackground)
            .clipShape(.rect(cornerRadius: CYAppDimens.radiusM))

            if showsCancelButton {
                Button("cancel".cyLocalized) {
                    text = ""
                    onCancel?()
                }
                .font(CYAppFont.bodyMedium)
                .foregroundStyle(CYAppColor.primary)
            }
        }
    }
}
