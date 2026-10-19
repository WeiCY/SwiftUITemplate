import SwiftUI
import CYAppCore

/// A single visible system text field for short ASCII numeric codes.
/// The host controls focus with `.focused`, and owns submission/network verification.
/// Initial/external values are normalized without calling onComplete. User edits call it
/// only when a different normalized value becomes complete; clearing/deleting re-arms it.
public struct CYVerificationCodeInput: View {
    @Binding private var code: String
    private let length: Int
    private let title: String?
    private let isDisabled: Bool
    private let onComplete: ((String) -> Void)?
    @Environment(\.isEnabled) private var isEnabled
    @State private var editing: CYVerificationCodeEditingState

    /// Nonpositive length is treated as one. No fixed cell width or hidden focus target.
    public init(code: Binding<String>, length: Int = 6, title: String? = nil,
                isDisabled: Bool = false, onComplete: ((String) -> Void)? = nil) {
        self._code = code
        self.length = max(1, length)
        self.title = title
        self.isDisabled = isDisabled
        self.onComplete = onComplete
        self._editing = State(initialValue: CYVerificationCodeEditingState(value: code.wrappedValue, length: max(1, length)))
    }

    public var body: some View {
        let label = title ?? "verification_code".cyLocalized
        let value = CYVerificationCodeEditingState.normalized(code, length: length)
        VStack(alignment: .leading, spacing: CYAppDimens.marginS) {
            Text(label)
                .font(CYAppFont.bodyMedium)
                .accessibilityHidden(true)
            TextField("verification_code_placeholder".cyLocalized, text: input, axis: .vertical)
                .lineLimit(1...)
                .textFieldStyle(.plain)
                .font(CYAppFont.mono)
                .foregroundStyle(CYAppColor.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.done)
                #if canImport(UIKit)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                #endif
                .padding(.horizontal, CYAppDimens.marginM)
                .padding(.vertical, CYAppDimens.marginS)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(CYAppColor.background, in: RoundedRectangle(cornerRadius: CYAppDimens.radiusM))
                .overlay {
                    RoundedRectangle(cornerRadius: CYAppDimens.radiusM)
                        .stroke(CYAppColor.border, lineWidth: CYAppDimens.borderWidth)
                        .allowsHitTesting(false)
                }
                .disabled(isDisabled)
                .accessibilityLabel(label)
                .accessibilityValue(value)
                .accessibilityHint(String(format: "verification_code_hint".cyLocalized, length))
            Text(String(format: "verification_code_progress".cyLocalized, value.count, length))
                .font(CYAppFont.caption)
                .foregroundStyle(CYAppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .opacity(isDisabled || !isEnabled ? 0.5 : 1)
        .onChange(of: code, initial: true) { _, _ in synchronize() }
        .onChange(of: length) { _, _ in synchronize() }
    }

    private var input: Binding<String> {
        Binding(get: { CYVerificationCodeEditingState.normalized(code, length: length) }, set: { value in
            editing.synchronize(code, length: length)
            let complete = editing.edit(value, length: length, isEnabled: isEnabled && !isDisabled)
            code = editing.value
            if let complete { onComplete?(complete) }
        })
    }

    private func synchronize() {
        editing.synchronize(code, length: length)
        if code != editing.value { code = editing.value }
    }
}

/// Local editing policy, independent of layout and focus, for deterministic regressions.
struct CYVerificationCodeEditingState {
    private(set) var value: String

    init(value: String, length: Int) {
        self.value = Self.normalized(value, length: length)
    }

    static func normalized(_ value: String, length: Int) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.lazy.filter { (48...57).contains($0.value) }.prefix(max(1, length))))
    }

    mutating func synchronize(_ value: String, length: Int) {
        self.value = Self.normalized(value, length: length)
    }

    mutating func edit(_ value: String, length: Int, isEnabled: Bool = true) -> String? {
        guard isEnabled else { return nil }
        let next = Self.normalized(value, length: length)
        let changed = next != self.value
        self.value = next
        return changed && next.count == max(1, length) ? next : nil
    }
}

#Preview("Narrow - largest text") {
    CYVerificationCodeInput(code: .constant("123456"))
        .frame(width: 240)
        .dynamicTypeSize(.accessibility5)
        .padding()
}
