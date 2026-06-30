import SwiftUI

// MARK: - 通用 UI 组件
//
// 容器组件与状态视图。按钮组件已拆分至 Buttons.swift。
//
// 包含：
// - CardView：卡片容器
// - EmptyStateView：空状态提示
// - LoadingView：加载骨架屏
//
// 用法：
// ```swift
// // 卡片容器
// CardView { VStack { Text("Title"); Text("Body") } }
//
// // 空状态
// EmptyStateView(title: "暂无数据", message: "下拉刷新", image: "tray")
//
// // 加载骨架屏
// LoadingView()
// ```

// MARK: - 容器组件

/// 卡片容器（圆角 + 阴影 + 内边距）
public struct CardView<Content: View>: View {
    public let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(CYAppDimens.marginM)
            .background(CYAppColor.background)
            .cornerRadius(CYAppDimens.radiusL)
            .shadow(color: CYAppColor.shadow, radius: CYAppDimens.shadowRadius, x: 0, y: CYAppDimens.shadowOffset)
    }
}

// MARK: - 状态视图

/// 空状态提示视图
public struct EmptyStateView: View {
    public let title: String
    public let message: String
    public let image: String
    
    public init(title: String, message: String, image: String) {
        self.title = title
        self.message = message
        self.image = image
    }
    
    public var body: some View {
        VStack(spacing: CYAppDimens.marginM) {
            Image(systemName: image)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(CYAppFont.h3)
                .bold()
                .foregroundColor(CYAppColor.textPrimary)
            
            Text(message)
                .font(CYAppFont.bodyMedium)
                .multilineTextAlignment(.center)
                .foregroundColor(CYAppColor.textSecondary)
        }
        .padding(CYAppDimens.marginXL)
    }
}

/// 加载骨架屏视图
public struct LoadingView: View {
    public init() {}
    public var body: some View {
        SkeletonList(rowCount: 3, cardCount: 2)
    }
}

#Preview("Design System Components") {
    ScrollView {
        VStack(spacing: 32) {
            
            // MARK: - Buttons Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Buttons")
                    .font(.title2)
                    .bold()
                
                PrimaryButton(title: "Primary Button", action: {})
                
                PrimaryButton(title: "Primary Loading", action: {}, isLoading: true)
                
                SecondaryButton(title: "Secondary Button", action: {})
            }
            .padding(.horizontal)
            
            Divider()
            
            // MARK: - Cards Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Cards")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)
                
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Title")
                            .font(CYAppFont.h3)
                            .foregroundColor(CYAppColor.textPrimary)
                        
                        Text("This is a generic card component that can hold any SwiftUI view content. It comes with default styling, shadow, and corner radius.")
                            .font(CYAppFont.bodyMedium)
                            .foregroundColor(CYAppColor.textSecondary)
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // MARK: - States Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Empty States")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)
                
                EmptyStateView(
                    title: "No Items Found",
                    message: "Try adjusting your search filters to find what you're looking for.",
                    image: "magnifyingglass"
                )
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Divider()
            
            // MARK: - Loading Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Loading State")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)
                
                LoadingView()
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
