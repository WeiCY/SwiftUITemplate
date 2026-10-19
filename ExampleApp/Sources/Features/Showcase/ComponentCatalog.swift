import SwiftUI
import CYAppCore
import CYAppDesignSystem
import CYAppUI

struct ComponentCatalog: View {
    let dependencies: AppDependencies
    @State private var dark = false
    @State private var large = false
    @State private var longText = false
    @State private var input = ""
    @State private var code = ""
    @State private var date = Date()
    @State private var enabled = true
    @State private var sheet = false
    @State private var snack = CYSnackBarManager()
    @Environment(CYAppRouter.self) private var router

    private var title: String { longText ? "一段很长的组件标题，用于验证换行、布局和大字体 / A long accessible component title" : "示例 / Example" }

    var body: some View {
        List {
            Section("预览环境 / Preview") {
                Text("第二品牌：Scheme → Arguments 添加 --alternate-brand 后重新运行。")
                Toggle("深色 / Dark", isOn: $dark)
                Toggle("大字体 / Accessibility size", isOn: $large)
                    .accessibilityIdentifier("catalog.large")
                Toggle("长文案 / Long text", isOn: $longText)
                    .accessibilityIdentifier("catalog.long")
            }
            Section("真实组合 / Recipes") {
                NavigationLink("全部公开组件索引 / Public API index") { PublicComponentIndex() }
                NavigationLink("更多组合 / More combinations") { AdditionalComponents() }
                NavigationLink("表单 / Form") { FormExample() }
                NavigationLink("验证码 / Verification code") { VerificationCodeExample() }
                NavigationLink("搜索与分页 / Search & pagination") { SearchExample() }
                NavigationLink("媒体 / Media") { MediaExample() }
            }
            Section("按钮 / Buttons") {
                PrimaryButton(title: title) { dependencies.toast.show(title) }
                PrimaryButton(title: "加载中 / Loading", action: {}, isLoading: true)
                PrimaryButton(title: "禁用 / Disabled", action: {}, isDisabled: true)
                SecondaryButton(title: title) { dependencies.toast.show(title) }
            }
            Section("输入 / Inputs") {
                CYTextField(title: "Email", placeholder: "name@example.com", text: $input, error: "校验错误 / Validation error")
                CYSearchBar(text: $input)
                CYVerificationCodeInput(code: $code)
                Toggle("原生 Toggle", isOn: $enabled)
                DatePicker("原生 DatePicker", selection: $date, displayedComponents: .date)
            }
            Section("卡片与列表 / Cards & rows") {
                CardView { Text(title) }
                CYSectionHeader(title: title)
                CYListRow(title: title)
                CYFlowLayout { CYTag(title: "SwiftUI", isSelected: true); CYBadge(title: "3") }
                CYTag(title: "局部浅色背景 / Local light color", isSelected: true,
                      selectedColor: .yellow, selectedTextColor: .black)
                    .accessibilityIdentifier("tag.localColor")
            }
            Section("状态 / States") {
                CYLoadingIndicator(message: nil)
                CYEmptyStateView(title: "空状态 / Empty", message: title)
                CYBaseView(isLoading: false, error: .network("示例错误 / Example failure"), onRetry: {}) { Text(title) }
            }
            Section("反馈 / Feedback") {
                Button("Toast") { dependencies.toast.show("Catalog Toast", type: .success) }
                    .accessibilityIdentifier("feedback.toast")
                #if canImport(UIKit)
                Button("触觉 / Haptics") { CYHapticFeedback.selection() }
                #endif
                Button("Loading") { dependencies.loading.show(title) }
                    .accessibilityIdentifier("feedback.loading")
                Button("Alert") { dependencies.alert.showAlert(title: "Example Alert", message: title) }
                    .accessibilityIdentifier("feedback.alert")
                Button("Snackbar") { snack.show(message: title) }
                Button("连续替换 Snackbar / Replace twice") {
                    snack.show(message: "Old", duration: 10)
                    snack.show(message: "Replacement survives: \(title)", duration: 0)
                }
                .accessibilityIdentifier("snackbar.replace")
                Button("Sheet") { sheet = true }
                Button("Router Sheet") { router.presentSheet(Text(title).padding()) }
            }
            Section("图片 / Image") {
                CYRemoteImageView(url: URL(string: "https://picsum.photos/800/600"), imageLoader: dependencies.imageLoader)
                    .frame(height: 160).clipped().accessibilityLabel("远程示例图片 / Remote sample")
            }
            Section("页面 / Layout") {
                NavigationLink("页面容器、底栏 / Page & bottom bar") { LayoutExample() }
                NavigationLink("分栏 / Split view") { SplitExample() }
            }
        }
        .navigationTitle("组件 / Components")
        .snackBar(manager: snack)
        .cyBottomSheet(isPresented: $sheet) { Text(title).padding() }
        .environment(\.colorScheme, dark ? .dark : .light)
        .dynamicTypeSize(large ? .accessibility2 : .large)

    }
}

private struct LayoutExample: View {
    var body: some View {
        CYPageContainer(title: "页面容器 / Page", subtitle: "Scroll + safe area") {
            ForEach(0..<20) { Text("Row \($0)").padding() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CYBottomActionBar { Text("底栏 / Bottom bar") } trailing: { Button("完成 / Done") {} }
        }
    }
}

private struct SplitExample: View {
    var body: some View {
        NavigationSplitView {
            List { NavigationLink("详情 / Detail") { Text("Detail") } }
        } detail: { Text("选择一项 / Select an item") }
    }
}

private struct AdditionalComponents: View {
    @State private var onboarding = false
    @State private var completed = false
    var body: some View {
        ScrollView {
            VStack(spacing: CYAppDimens.marginM) {
                CYPageActionBar(title: "Action bar", leading: { Button("Back") {} }, trailing: { Button("More") {} })
                SkeletonRow()
                SkeletonCard()
                SkeletonList(rowCount: 2)
                LoadingView()
                CYLoadMoreButton(isLoading: false, hasMore: true, action: {})
                CYToastView(message: "Toast content", type: .info)
                CYBottomActionBar(leading: { Text("Selection") }, trailing: { Button("Save") {} })
                Text("Typewriter").typewriter(text: "Updated text", trigger: true)
                Button("Onboarding") { completed = false; onboarding = true }
            }.padding()
        }
        .sheet(isPresented: $onboarding) {
            #if canImport(UIKit)
            CYOnboardingView(hasCompleted: $completed, pages: [.init(icon: "star", title: "Welcome", description: "Host-owned content")])
                .onChange(of: completed) { _, value in if value { onboarding = false } }
            #else
            Text("Onboarding uses iOS page-style TabView")
            #endif
        }
    }
}

// Searchable public surface, including support types; snippets show required host bindings/services.
private struct PublicComponentIndex: View {
    @State private var query = ""
    var body: some View {
        List {
            ForEach(Self.entries.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { entry in
                NavigationLink(entry.name) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(entry.note)
                            Text(entry.sample).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Text("完整能力矩阵及未验收项：docs/MODULE_COMPONENT_REVIEW.md")
                        }.padding()
                    }.navigationTitle(entry.name)
                }
            }
        }.searchable(text: $query).navigationTitle("Public API index")
    }
    private struct Entry: Identifiable {
        let name: String
        let sample: String
        let note: String
        var id: String { name }
    }
    private struct Group {
        let names: String
        let sample: String
        let note: String
        init(_ names: String, _ sample: String, _ note: String) {
            self.names = names
            self.sample = sample
            self.note = note
        }
    }
    private static let groups: [Group] = [
        .init(
            "PrimaryButton SecondaryButton CYScaledButtonStyle",
            "PrimaryButton(title: \"Save\", action: {})",
            "Buttons: loading / disabled; see Buttons section."
        ),
        .init(
            "CYTextField CYSearchBar",
            "CYTextField(placeholder: \"Name\", text: $text)",
            "Input bindings; Form recipe demonstrates focus and submit."
        ),
        .init(
            "CYVerificationCodeInput",
            "CYVerificationCodeInput(code: $code, onComplete: { value in focus = .next }).focused($focus, equals: .code)",
            "One visible system input; ASCII 0...9; initial/external normalization is silent. See Verification code recipe."
        ),
        .init(
            "CYPaginatedListView",
            "CYPaginatedListView(viewModel: model, onRefresh: { await model.refresh() }, onLoadMore: { await model.loadMore() }) { " +
            "Text($0.id.description) }",
            "Compatible template ViewModel adapter; Search recipe."
        ),
        .init(
            "CYPaginationState CYPaginatedListContent",
            "CYPaginatedListContent(state: model.state, onRefresh: { await model.refresh() }, onLoadMore: { await model.append() }, onRetry: { " +
            "await model.retry() }) { Text($0.id.description) }",
            "Host-owned state: ConsumerFixtures/DesignSystemConsumer. Owns a List; do not nest in ScrollView."
        ),
        .init(
            "CYLoadMoreButton",
            "CYLoadMoreButton(isLoading: false, hasMore: true, action: {})",
            "More combinations; host owns page and duplicate-request guard."
        ),
        .init(
            "ShimmerModifier SkeletonRow SkeletonCard SkeletonList",
            "SkeletonList(rowCount: 2)",
            "More combinations; shimmer placeholder, not actual loading ownership."
        ),
        .init(
            "CYPageActionBar",
            "CYPageActionBar(title: \"Title\")",
            "More combinations; one-line toolbar labels."
        ),
        .init(
            "CYSearchFilterBar",
            "CYSearchFilterBar(text: $text, onSearch: {})",
            "Search recipe; native keyboard behavior."
        ),
        .init(
            "CYPageContainer",
            "CYPageContainer(title: \"Title\") { Text(\"Content\") }",
            "Page recipe; defaults to scrolling. Pass usesScrollView: false with List/ScrollView content."
        ),
        .init(
            "CYEmptyStateView",
            "CYEmptyStateView(title: \"Empty\", message: \"Try again\")",
            "States section; optional action."
        ),
        .init(
            "CYBottomActionBar",
            "Text(\"Content\").safeAreaInset(edge: .bottom, spacing: 0) { CYBottomActionBar(leading: { Text(\"Selection\") }, trailing: { Button(\"Save\") {} }) }",
            "Page recipe / More combinations; native safeAreaInset."
        ),
        .init(
            "CYFlowLayout CYTag CYTagGroup CYBadge",
            "CYFlowLayout { CYTag(title: \"SwiftUI\", isSelected: true); CYBadge(title: \"3\") }",
            "Cards & rows section; selectedIDs is a value snapshot. Update host selection in each tag action."
        ),
        .init(
            "CYListRow CYSectionHeader CardView",
            "CardView { CYListRow(title: \"Title\") }",
            "Cards & rows section; no network or business state."
        ),
        .init(
            "CYLoadingIndicator LoadingView",
            "CYLoadingIndicator(message: \"Loading\")",
            "States / More combinations; style via CYLoadingStyle."
        ),
        .init(
            "CYBottomSheetModifier",
            "Text(\"Page\").cyBottomSheet(isPresented: $sheet) { Text(\"Sheet\") }",
            "Feedback section; native sheet owns presentation."
        ),
        .init(
            "CYSnackBarManager CYSnackBar CYSnackBarModifier",
            "Text(\"Page\").snackBar(manager: snack) // @State var snack = CYSnackBarManager()",
            "Feedback section; call snack.show(message: \"Saved\")."
        ),
        .init(
            "CYBaseView CYDefaultErrorView",
            "CYBaseView(isLoading: false, error: nil, onRetry: {}) { Text(\"Content\") }",
            "States section; CYAppError or template ViewModel convenience."
        ),
        .init(
            "CYAppDimens CYDesignTokens CYDesignConfiguration CYAppColor CYAppFont",
            "CYDesignConfiguration.configure(.alternate) // app startup, before rendering",
            "Process-wide brand, not window-scoped. Run with --alternate-brand."
        ),
        .init(
            "CYToastPosition CYToastIconColorStrategy CYFeedbackShadow CYToastStyle CYLoadingIndicatorStyle CYLoadingCardStyle CYLoadingStyle " +
            "CYErrorStyle CYFeedbackConfiguration",
            "CYFeedbackConfiguration.reset()",
            "Process-wide feedback styles; style properties can be set at startup."
        ),
        .init(
            "CYAppState",
            "CYAppState() // retain in @State and inject into environment",
            "Process-wide localization defaults; independent business state stays in the host."
        ),
        .init(
            "CYAlertManagerModifier CYToastView CYLoadingOverlay",
            "Text(\"Page\").feedbackOverlay(toastManager: host.toast, loadingManager: host.loading).alertManager(manager: host.alert)",
            "ConsumerFixtures/CustomComposition: calls and mounts must share instances."
        ),
        .init(
            "CYRemoteImageView",
            "CYRemoteImageView(url: url, imageLoader: host.images)",
            "Injected local loader in UI automation; URL changes / exit cancel loads."
        ),
        .init(
            "TypewriterModifier",
            "Text(\"Text\").typewriter(text: \"New text\", trigger: true)",
            "More combinations; reduced motion supported."
        ),
        .init(
            "RectCorner",
            "Text(\"Corner\").cornerRadius(8, corners: [.topLeft, .topRight])",
            "Corner helper; layout extensions in View+Extensions.swift."
        ),
        .init(
            "CYMediaPicker CYCameraView CYMediaPickerController",
            "CYMediaPickerController(onConfirm: { items in }, onCancel: {})",
            "iOS + Photos; Media recipe. Real device permissions / camera need manual acceptance."
        ),
        .init(
            "CYMediaSelectionManager CYMediaType CYMediaPickerStyle CYMediaSource CYMediaFilter CYMediaItem CYAlbumInfo CYPhotoAssetLoader",
            "CYMediaSelectionManager(maxSelection: 3) // native PHAsset input; CYPhotoAssetLoader.shared loads assets",
            "iOS media support types; MediaTypes.swift lists source/filter cases. Not business models."
        ),
        .init(
            "CYShareSheet",
            "CYShareSheet(items: [\"Share text\"])",
            "iOS; present with native sheet. Native share targets depend on device."
        ),
        .init(
            "CYOnboardingPage CYOnboardingView",
            "CYOnboardingView(hasCompleted: $completed, pages: [.init(icon: \"star\", title: \"Welcome\", description: \"Host text\")])",
            "Onboarding view iOS; page model also macOS. More combinations."
        ),
        .init(
            "CYSheetItem CYAppRouter",
            "let router = CYAppRouter(tabs: [\"home\"]) // NavigationStack(path: router.binding(for: \"home\"))",
            "Host-defined route values; inject same router into call site / NavigationStack."
        )
    ]
    private static let entries: [Entry] = groups.flatMap { group in
        group.names.split(separator: " ").map { Entry(name: String($0), sample: group.sample, note: group.note) }
    }
}
