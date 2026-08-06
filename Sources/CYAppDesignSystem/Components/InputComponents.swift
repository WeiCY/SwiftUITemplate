import SwiftUI
import CYAppCore

// MARK: - 文本输入框

/// 标准文本输入框。
///
/// 内置标题、图标、错误提示和深色模式适配。
public struct CYTextField: View {
    let title: String?
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    let error: String?
    let isDisabled: Bool

    @Binding var text: String

    public init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        error: String? = nil,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.error = error
        self.isDisabled = isDisabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYAppDimens.marginS) {
            if let title {
                Text(title)
                    .font(CYAppFont.bodyMedium)
                    .foregroundColor(CYAppColor.textPrimary)
            }

            HStack(spacing: CYAppDimens.marginS) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundColor(CYAppColor.textSecondary)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.textPrimary)
                .disabled(isDisabled)
            }
            .padding(CYAppDimens.marginM)
            .background(
                RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                    .stroke(
                        error != nil ? CYAppColor.error : CYAppColor.border,
                        lineWidth: CYAppDimens.borderWidth
                    )
            )
            .background(CYAppColor.background)
            .cornerRadius(CYAppDimens.radiusM)

            if let error {
                Text(error)
                    .font(CYAppFont.caption)
                    .foregroundColor(CYAppColor.error)
            }
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
                    .foregroundColor(CYAppColor.textSecondary)

                TextField(placeholder, text: $text)
                    .font(CYAppFont.bodyMedium)
                    .foregroundColor(CYAppColor.textPrimary)
                    .submitLabel(.search)
                    .onSubmit { onSearch?() }

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CYAppColor.textTertiary)
                    }
                }
            }
            .padding(CYAppDimens.marginS)
            .background(CYAppColor.secondaryBackground)
            .cornerRadius(CYAppDimens.radiusM)

            if showsCancelButton {
                Button("cancel".cyLocalized) {
                    text = ""
                    onCancel?()
                }
                .font(CYAppFont.bodyMedium)
                .foregroundColor(CYAppColor.primary)
            }
        }
    }
}

// MARK: - 验证码输入

/// 验证码/一次性密码输入组件。
///
/// 显示为固定长度的输入框，自动过滤非数字字符。
public struct CYVerificationCodeInput: View {
    let length: Int
    let boxSize: CGFloat
    let spacing: CGFloat

    @Binding var code: String
    @FocusState private var isFocused: Bool

    public init(
        code: Binding<String>,
        length: Int = 6,
        boxSize: CGFloat = 48,
        spacing: CGFloat = 12
    ) {
        self._code = code
        self.length = max(1, length)
        self.boxSize = boxSize
        self.spacing = spacing
    }

    public var body: some View {
        ZStack {
            TextField("", text: $code)
                #if canImport(UIKit)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .opacity(0)
                .focused($isFocused)
                .onChange(of: code) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    code = String(digits.prefix(length))
                }

            HStack(spacing: spacing) {
                ForEach(0..<length, id: \.self) { index in
                    digitBox(at: index)
                }
            }
        }
        .frame(height: boxSize)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let isActive = index == characters.count

        return Text(character)
            .font(CYAppFont.h2)
            .foregroundColor(CYAppColor.textPrimary)
            .frame(width: boxSize, height: boxSize)
            .background(CYAppColor.background)
            .overlay(
                RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                    .stroke(
                        isActive ? CYAppColor.primary : CYAppColor.border,
                        lineWidth: isActive ? 2 : CYAppDimens.borderWidth
                    )
            )
            .cornerRadius(CYAppDimens.radiusM)
    }
}
