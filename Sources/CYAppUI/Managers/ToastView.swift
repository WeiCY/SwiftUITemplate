import SwiftUI
import CYAppCore
import CYAppDesignSystem

/// Toast 消息视图
/// 显示带图标和颜色的提示消息
public struct CYToastView: View {
    public let message: String
    public let type: CYToastType
    
    public init(message: String, type: CYToastType) {
        self.message = message
        self.type = type
    }
    
    public var body: some View {
        HStack(spacing: CYAppDimens.marginS + 4) {
            Image(systemName: type.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(type.color)
            
            Text(message)
                .font(CYAppFont.bodySmall)
                .foregroundColor(CYAppColor.textPrimary)
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CYAppDimens.marginM)
        .padding(.vertical, CYAppDimens.marginS + 4)
        .background(CYAppColor.background)
        .cornerRadius(CYAppDimens.radiusM)
        .shadow(color: CYAppColor.shadow, radius: CYAppDimens.shadowRadius, x: 0, y: CYAppDimens.shadowOffset)
        .padding(.horizontal, CYAppDimens.marginM)
    }
}

/// CYToastType 的 SwiftUI 颜色扩展
/// 分离到此处因为 Color 依赖 SwiftUI
extension CYToastType {
    var color: Color {
        switch self {
        case .info: return CYAppColor.info
        case .success: return CYAppColor.success
        case .error: return CYAppColor.error
        case .warning: return CYAppColor.warning
        }
    }
}

// MARK: - 预览

#Preview("Toast Types") {
    VStack(spacing: 16) {
        CYToastView(message: "Operation completed successfully!", type: .success)
        CYToastView(message: "Something went wrong. Please try again.", type: .error)
        CYToastView(message: "New update available.", type: .info)
        CYToastView(message: "Storage is almost full.", type: .warning)
    }
    .padding()
    .background(CYAppColor.secondaryBackground)
}
