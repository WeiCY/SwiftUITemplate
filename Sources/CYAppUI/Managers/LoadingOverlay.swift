import SwiftUI
import Observation
import CYAppDesignSystem

/// 全局加载遮罩视图
/// 毛玻璃背景 + 脉冲动画指示器 + 可选消息文本
public struct CYLoadingOverlay: View {
    public let message: String?
    
    public init(message: String?) {
        self.message = message
    }
    
    @State private var pulseScale: CGFloat = 0.9
    
    public var body: some View {
        ZStack {
            // 单一毛玻璃遮罩：材质 + 轻量暗化，避免多层背景叠加致色偏暗
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.2))
                .ignoresSafeArea()
            
            VStack(spacing: CYAppDimens.marginL) {
                // 脉冲动画指示器
                ZStack {
                    Circle()
                        .fill(CYAppColor.primary.opacity(0.1))
                        .frame(width: CYAppDimens.loaderSize, height: CYAppDimens.loaderSize)
                        .scaleEffect(pulseScale)
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(CYAppColor.primary)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                }
                
                if let message = message {
                    Text(message)
                        .font(CYAppFont.bodySmall)
                        .foregroundStyle(CYAppColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, CYAppDimens.marginXL)
            .padding(.vertical, CYAppDimens.marginL)
            .background(
                RoundedRectangle(cornerRadius: CYAppDimens.radiusCard, style: .continuous)
                    .fill(CYAppColor.background)
                    .shadow(color: CYAppColor.shadow, radius: 12, y: 4)
            )
        }
    }
}
