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
            // 毛玻璃背景
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack(spacing: 20) {
                // 脉冲动画指示器
                ZStack {
                    Circle()
                        .fill(CYAppColor.primary.opacity(0.1))
                        .frame(width: 64, height: 64)
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
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CYAppColor.background)
                    .shadow(color: CYAppColor.shadow, radius: 12, y: 4)
            )
        }
    }
}
