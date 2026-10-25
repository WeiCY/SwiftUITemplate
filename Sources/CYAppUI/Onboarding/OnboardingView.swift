#if canImport(UIKit)
import SwiftUI
import CYAppDesignSystem

/// Paged onboarding; accessibility text sizes use one scrollable page with explicit navigation controls.
public struct CYOnboardingView: View {
    @Binding var hasCompleted: Bool
    @State private var currentPage = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let pages: [CYOnboardingPage]

    public init(hasCompleted: Binding<Bool>, pages: [CYOnboardingPage] = CYOnboardingPage.allPages) {
        self._hasCompleted = hasCompleted
        self.pages = pages
    }

    public var body: some View {
        GeometryReader { geometry in
            Group {
                if pages.isEmpty {
                    Color.clear.onAppear { hasCompleted = true }
                } else if dynamicTypeSize.isAccessibilitySize || geometry.size.height < 400 {
                    ScrollView {
                        VStack(spacing: CYAppDimens.marginL) {
                            skipButton
                            pageView(pages[min(currentPage, pages.count - 1)])
                            controls
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: CYAppDimens.marginM) {
                        skipButton
                        TabView(selection: $currentPage) {
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                ScrollView { pageView(page).padding(.vertical) }.tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        controls
                    }
                    .padding()
                }
            }
            .background(CYAppColor.secondaryBackground.ignoresSafeArea())
            .onChange(of: pages.count) { _, count in currentPage = min(currentPage, max(0, count - 1)) }
        }
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("onboarding_skip".cyLocalized) { hasCompleted = true }
                .font(CYAppFont.button)
                .frame(minHeight: 44)
        }
    }

    private var controls: some View {
        VStack(spacing: CYAppDimens.marginM) {
            Text("\(currentPage + 1) / \(pages.count)")
                .monospacedDigit()
                .accessibilityLabel("onboarding_progress".cyLocalized)
                .accessibilityValue("\(currentPage + 1) / \(pages.count)")
            if currentPage >= pages.count - 1 {
                PrimaryButton(title: "onboarding_start".cyLocalized, action: { hasCompleted = true })
            } else {
                PrimaryButton(title: "onboarding_next".cyLocalized, action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage += 1 }
                })
            }
            if currentPage > 0 {
                Button("onboarding_previous".cyLocalized) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage -= 1 }
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func pageView(_ page: CYOnboardingPage) -> some View {
        VStack(spacing: CYAppDimens.marginL) {
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(CYAppColor.primary)
                .accessibilityHidden(true)
            Text(page.title)
                .font(CYAppFont.h2)
                .accessibilityAddTraits(.isHeader)
            Text(page.description)
                .font(CYAppFont.bodyLarge)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(CYAppColor.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}
#endif
