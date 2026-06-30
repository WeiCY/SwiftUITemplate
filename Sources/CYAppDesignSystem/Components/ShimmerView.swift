import SwiftUI

// MARK: - 骨架屏闪烁修饰符
// 从左到右的渐变闪烁效果，用于骨架屏加载状态

public struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -1.5
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.plusLighter)
                    .offset(x: phase * 200)
                    .mask(content)
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            phase = 1.5
                        }
                    }
                }
            }
    }
}

extension View {
    /// 骨架屏闪烁效果修饰符
    /// - Parameter isActive: 是否激活闪烁动画
    public func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - 骨架占位视图
// 预置的骨架占位视图，用于数据加载前的占位显示

/// 单行骨架占位
public struct SkeletonRow: View {
    public var height: CGFloat = 14
    public var widthRatio: CGFloat = 1.0
    
    public init(height: CGFloat = 14, widthRatio: CGFloat = 1.0) {
        self.height = height
        self.widthRatio = widthRatio
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(CYAppColor.tertiaryBackground)
            .frame(width: nil, height: height)
            .frame(maxWidth: .infinity)
            .shimmer()
    }
}

/// 骨架卡片占位（模拟内容卡片）
public struct SkeletonCard: View {
    public var lineCount: Int = 3
    
    public init(lineCount: Int = 3) {
        self.lineCount = lineCount
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行（更宽更高）
            RoundedRectangle(cornerRadius: 6)
                .fill(CYAppColor.tertiaryBackground)
                .frame(height: 18)
                .frame(maxWidth: .infinity)
                .shimmer()
            
            // 内容行
            ForEach(0..<lineCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(CYAppColor.tertiaryBackground)
                    .frame(height: 12)
                    .frame(maxWidth: index == lineCount - 1 ? 200 : .infinity)
                    .shimmer()
            }
        }
        .padding(CYAppDimens.marginM)
        .background(
            RoundedRectangle(cornerRadius: CYAppDimens.radiusL)
                .fill(CYAppColor.background)
                .shadow(color: CYAppColor.shadow, radius: 4, y: 2)
        )
    }
}

/// 骨架列表占位（多行骨架）
public struct SkeletonList: View {
    public var rowCount: Int = 4
    public var cardCount: Int = 0
    
    public init(rowCount: Int = 4, cardCount: Int = 0) {
        self.rowCount = rowCount
        self.cardCount = cardCount
    }
    
    public var body: some View {
        VStack(spacing: CYAppDimens.marginM) {
            // 卡片骨架
            ForEach(0..<cardCount, id: \.self) { _ in
                SkeletonCard()
            }
            
            // 行骨架
            if rowCount > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<rowCount, id: \.self) { index in
                        SkeletonRow(widthRatio: index == rowCount - 1 ? 0.6 : 1.0)
                    }
                }
            }
        }
    }
}

#Preview("Shimmer Components") {
    ScrollView {
        VStack(spacing: 24) {
            Text("SkeletonRow")
                .font(.headline)
            SkeletonRow()
            SkeletonRow(height: 20)
            
            Divider()
            
            Text("SkeletonCard")
                .font(.headline)
            SkeletonCard()
            SkeletonCard(lineCount: 5)
            
            Divider()
            
            Text("SkeletonList")
                .font(.headline)
            SkeletonList(rowCount: 5, cardCount: 2)
        }
        .padding()
    }
}
