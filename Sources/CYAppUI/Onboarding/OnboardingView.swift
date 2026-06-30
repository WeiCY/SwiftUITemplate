#if canImport(UIKit)
import SwiftUI
import CYAppDesignSystem

/// 新手引导视图
/// 使用 TabView + .page 样式实现滑动引导
public struct CYOnboardingView: View {
    @Binding var hasCompleted: Bool
    @State private var currentPage = 0
    
    private let pages = CYOnboardingPage.allPages
    
    public init(hasCompleted: Binding<Bool>) {
        self._hasCompleted = hasCompleted
    }

    public var body: some View {
        ZStack {
            CYAppColor.secondaryBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasCompleted = true
                            }
                        }
                        .font(CYAppFont.button)
                        .foregroundStyle(CYAppColor.textSecondary)
                        .padding(.horizontal, CYAppDimens.marginL)
                        .padding(.top, CYAppDimens.marginM)
                    }
                }
                .frame(height: 44)
                
                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        onboardingPageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // 底部：页面指示器 + 按钮
                VStack(spacing: CYAppDimens.marginL) {
                    // 页面指示器
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? CYAppColor.primary : CYAppColor.border)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // 操作按钮
                    if currentPage == pages.count - 1 {
                        // 最后一页：开始按钮
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasCompleted = true
                            }
                        } label: {
                            Text("开始使用")
                                .font(CYAppFont.button)
                                .foregroundStyle(CYAppColor.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: CYAppDimens.buttonHeight)
                                .background(CYAppColor.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CYAppDimens.radiusL))
                        }
                        .buttonStyle(CYScaledButtonStyle())
                    } else {
                        // 其他页：下一页按钮
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        } label: {
                            Text("下一页")
                                .font(CYAppFont.button)
                                .foregroundStyle(CYAppColor.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: CYAppDimens.buttonHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: CYAppDimens.radiusL)
                                        .stroke(CYAppColor.primary, lineWidth: CYAppDimens.borderWidth)
                                )
                        }
                        .buttonStyle(CYScaledButtonStyle())
                    }
                }
                .padding(.horizontal, CYAppDimens.marginL)
                .padding(.bottom, CYAppDimens.marginXXL)
            }
        }
    }
    
    private func onboardingPageView(_ page: CYOnboardingPage) -> some View {
        VStack(spacing: CYAppDimens.marginXL) {
            Spacer()
            
            // 图标
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(CYAppColor.primary)
                .frame(width: 120, height: 120)
            
            // 标题
            Text(page.title)
                .font(CYAppFont.h2)
                .foregroundStyle(CYAppColor.textPrimary)
                .multilineTextAlignment(.center)
            
            // 描述
            Text(page.description)
                .font(CYAppFont.bodyLarge)
                .foregroundStyle(CYAppColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, CYAppDimens.marginXL)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    CYOnboardingView(hasCompleted: .constant(false))
}
#endif
