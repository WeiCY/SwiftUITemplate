# CYSwiftTemplate 使用指南

## 快速开始

### 1. 集成到项目

在 Xcode 中选择 **File → Add Package Dependencies**，输入仓库地址：

```
https://github.com/your-org/CYSwiftTemplate
```

按需引入四个库：

| 库名 | 用途 | 何时引入 |
|---|---|---|
| `CYAppCore` | 网络、缓存、DI、管理器、权限 | **必选** |
| `CYFeedbackStyle` | Toast/Loading 样式定义 | 有 UI 反馈时引入 |
| `CYAppDesignSystem` | 颜色、字体、间距、基础组件 | 有 UI 时引入 |
| `CYAppUI` | 路由、AppState、Toast 视图、Loading 视图、引导页 | 有 UI 时引入 |
| `CYAppPersistence` | SwiftData 持久化（可选） | 需本地存储时引入 |

### 2. 配置环境与网络

在 `@main App` 初始化时配置，**不需要修改模板源码**：

```swift
import SwiftUI
import CYAppCore
import CYFeedbackStyle
import CYAppUI

@main
struct MyApp: App {
    init() {
        // 配置环境与网络请求
        CYAppConfiguration.configure(
            environment: .production,
            baseURL: "https://api.your-domain.com",
            defaultHeaders: [
                "X-App-Platform": "iOS",
                "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            ],
            timeoutInterval: 30
        )

        // 配置业务状态码策略
        CYBusinessCodePolicy.configure {
            $0.successCodes = [0, 200]
            $0.tokenExpiredCodes = [401, 10001]
            $0.needReLoginCodes = [403]
            $0.displayMode = .toast
        }

        // 配置全局反馈样式
        CYFeedbackConfiguration.configure(
            toastStyle: CYToastStyle(position: .center),
            loadingStyle: .default
        )
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .preferredColorScheme(appState.theme.colorScheme)
                .id(appState.language)
                .feedbackOverlay()
        }
    }
}
```

#### 多环境配置示例

在业务 App 的 Build Configuration 中通过 `.xcconfig` 注入：

**Debug.xcconfig**
```
API_BASE_URL = https:/$()/dev-api.example.com
```

**Release.xcconfig**
```
API_BASE_URL = https:/$()/api.example.com
```

**Info.plist**
```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

**App 启动代码**
```swift
let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""

CYAppConfiguration.configure(
    environment: .production,
    baseURL: baseURL,
    defaultHeaders: ["X-App-Platform": "iOS"]
)
```

---

## 网络请求

### Step 1: 定义 CYEndpoint（API 路径）

```swift
import CYAppCore

enum UserEndpoint: CYEndpoint {
    case profile
    case list(page: Int)
    case update

    var path: String {
        switch self {
        case .profile:  return "/api/user/profile"
        case .list:     return "/api/user/list"
        case .update:   return "/api/user/update"
        }
    }

    var method: CYHTTPMethod {
        switch self {
        case .profile, .list: return .get
        case .update:         return .post
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page):
            return [URLQueryItem(name: "page", value: "\(page)")]
        default: return nil
        }
    }
}
```

### Step 2: 定义数据模型（struct + Codable）

```swift
struct User: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let avatar: String?
    let email: String?
}

struct UpdateProfileBody: Encodable, Sendable {
    let name: String
    let email: String
}
```

> **为什么用 `struct` 而不是 `NSObject`？**
> Swift 的 `Codable` 协议由编译器自动生成 JSON 解析代码，无需 MJExtension 等运行时反射库。
> 字段写错 → 编译报错，而非运行时崩溃。

### Step 3: 发起请求

```swift
let networkClient = CYAppContainer.shared.networkClient

// ─── 方式 1：自动解包（推荐）───
// 后端返回 {"code": 0, "data": {...}, "message": "ok"}
let user: User = try await networkClient.request(UserEndpoint.profile)

// ─── 方式 2：带 Encodable body 的 POST ───
let body = UpdateProfileBody(name: "John", email: "john@example.com")
let updatedUser: User = try await networkClient.post(UserEndpoint.update, body: body)

// ─── 方式 3：获取完整响应（需要手动处理业务码）───
let response: CYAPIResponse<User> = try await networkClient.requestRaw(UserEndpoint.profile)
switch response.businessResult {
case .success:
    let user = response.data
case .tokenExpired:
    // 框架已自动刷新 Token
case .businessError(_, let message, let display):
    if display == .alert { /* showAlert */ }
    else { CYToastManager.shared.show(message, type: .error) }
default: break
}
```

### Step 4: 在 ViewModel 中使用

```swift
import CYAppCore

@MainActor
@Observable
final class ProfileViewModel: CYBaseViewModel {
    var user: User?

    func fetchProfile() async {
        await executeTask { [weak self] in
            self?.user = try await CYAppContainer.shared.networkClient
                .request(UserEndpoint.profile)
        }
    }

    func updateProfile(name: String, email: String) async {
        await executeTask { [weak self] in
            let body = UpdateProfileBody(name: name, email: email)
            self?.user = try await CYAppContainer.shared.networkClient
                .post(UserEndpoint.update, body: body)
        }
    }
}
```

`executeTask` 自动管理 `isLoading` / `error` / `retry` 三种状态。

### Step 5: 在 View 中使用

```swift
import SwiftUI
import CYAppCore
import CYAppDesignSystem

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        CYBaseView(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            onRetry: { Task { await viewModel.fetchProfile() } }
        ) {
            if let user = viewModel.user {
                VStack {
                    Text(user.name).font(CYAppFont.h2)
                    Text(user.email ?? "").font(CYAppFont.bodyMedium)
                }
            }
        }
        .task { await viewModel.fetchProfile() }
    }
}
```

---

## 高级网络功能

### 自定义请求拦截器

```swift
import CYAppCore

struct EncryptionInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest) async {
        if let body = request.httpBody {
            let encrypted = encrypt(body)
            request.httpBody = encrypted
            request.setValue("encrypted", forHTTPHeaderField: "X-Content-Encoding")
        }
    }

    private func encrypt(_ data: Data) -> Data {
        return data
    }
}

// 在 App 启动时注册
CYAppConfiguration.configure(
    environment: .production,
    baseURL: "https://api.example.com",
    requestInterceptors: [
        EncryptionInterceptor(),
        CYLoggingInterceptor()
    ]
)
```

### 请求去重

```swift
let deduplicator = CYAppContainer.shared.requestDeduplicator

let user: User = try await deduplicator.request(
    UserEndpoint.profile,
    using: networkClient
)
// 500ms 内的重复请求会自动合并，只发起一次网络请求
```

### 文件上传

```swift
let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()

let avatar: Avatar = try await networkClient.upload(
    UserEndpoint.uploadAvatar,
    data: imageData,
    fileName: "avatar.jpg",
    mimeType: "image/jpeg",
    paramName: "file",
    additionalParams: ["user_id": .string("123")]
)
```

### 文件下载

```swift
let fileURL = try await networkClient.download(
    FileEndpoint.downloadPDF(id: "doc123"),
    to: documentsDirectory.appendingPathComponent("doc.pdf")
)
```

---

## 模型与解析（替代 MJExtension）

### OC → Swift 对照表

| OC 时代 | Swift 方案 | 说明 |
|---|---|---|
| `NSObject` + `MJExtension` | `struct: Codable` | 编译器生成解析代码，非运行时反射 |
| `[User yy_modelWithJSON:dict]` | `JSONDecoder().decode(User.self, from: data)` | 类型安全 |
| `[User mj_objectArrayWithKeyValuesArray:arr]` | `JSONDecoder().decode([User].self, from: data)` | 数组也一行搞定 |
| `model.mj_keyValues` | `JSONEncoder().encode(model)` | 模型转 JSON |
| 字段名不匹配 → 运行时 nil | 字段名不匹配 → **编译报错** | 提前发现问题 |

### 字段名映射

模板已配置全局 `convertFromSnakeCase`，后端 `created_at` 自动映射到 `createdAt`。如需特殊映射：

```swift
struct Product: Decodable {
    let id: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}
```

### 可选字段与嵌套模型

```swift
struct OrderResponse: Decodable, Sendable {
    let order: Order
    let items: [OrderItem]
}

struct User: Decodable, Sendable {
    let id: Int
    let name: String
    let avatar: String?     // 可选 — 后端可能不返回
    let bio: String?        // 可选
}
```

`JSONDecoder` 自动处理缺失字段和嵌套结构的递归解析。

---

## 状态管理

### CYAppState（全局状态，位于 CYAppUI 层）

跨页面共享的状态放 `CYAppState`：

```swift
struct SettingsView: View {
    @Environment(CYAppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        VStack {
            Text(appState.user?.name ?? "Guest")
            Picker("Theme", selection: $state.theme) {
                ForEach(CYAppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
        }
    }
}
```

### CYBaseViewModel（页面级状态）

单页面的 loading/error/data 放 `CYBaseViewModel` 子类：

```swift
@Observable
final class HomeViewModel: CYBaseViewModel {
    var items: [Item] = []

    func fetchItems() async {
        await executeTask { [weak self] in
            self?.items = try await CYAppContainer.shared.networkClient
                .request(ItemEndpoint.list)
        }
    }
}
```

### 分工原则

| 放 CYAppState | 放 ViewModel |
|---|---|
| 当前用户 / 登录状态 | 页面列表数据 |
| 选中 Tab / 路由状态 | 页面 loading / error |
| 主题偏好 / 语言 | 搜索关键词 |
| 引导页完成状态 | 表单输入内容 |

---

## 导航路由

### 定义路由

```swift
enum Route: Hashable {
    case productDetail(id: Int)
    case settings
    case profile(userId: String)
}
```

### 导航操作

```swift
// 前进
CYAppRouter.shared.navigate(to: Route.productDetail(id: 123))

// 后退
CYAppRouter.shared.pop()

// 回到根页面
CYAppRouter.shared.popToRoot()

// 跨 Tab 导航（自动切换到目标 Tab）
CYAppRouter.shared.navigate(to: Route.settings, on: .profile)
```

### 在 View 中使用

```swift
struct RootView: View {
    @Bindable var router = CYAppRouter.shared
    @Environment(CYAppState.self) private var appState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(CYAppTab.allCases, id: \.self) { tab in
                NavigationStack(path: router.binding(for: tab)) {
                    HomeView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .productDetail(let id):
                                ProductDetailView(id: id)
                            case .settings:
                                SettingsView()
                            case .profile(let userId):
                                ProfileView(userId: userId)
                            }
                        }
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
            }
        }
        .onAppear { router.bind(to: appState) }
        .feedbackOverlay()
    }
}
```

---

## 组件速查

### Toast 提示

```swift
// 默认用法（全局单例）
CYToastManager.shared.show("保存成功", type: .success)
CYToastManager.shared.show("网络错误", type: .error, duration: 3.0)

// 自定义管理器实例（通过 DI 注入）
let myToast = CYAppContainer.shared.toastManager
myToast.show("来自 DI 的消息", type: .info)
```

### Loading 遮罩

```swift
// 默认用法
CYLoadingManager.shared.show("加载中…")
// ... 执行操作 ...
CYLoadingManager.shared.hide()

// DI 注入方式
let myLoading = CYAppContainer.shared.loadingManager
myLoading.show("自定义加载")
```

### Alert 弹窗

```swift
// 默认用法
CYAlertManager.shared.showAlert(title: "提示", message: "操作成功")
CYAlertManager.shared.showSuccess("保存成功")
CYAlertManager.shared.showError("网络错误")

// 确认对话框
CYAlertManager.shared.showConfirmation(
    title: "确认删除",
    message: "此操作不可撤销",
    confirmTitle: "删除",
    confirmStyle: true
) {
    // 执行删除
}

// DI 注入方式
let myAlert = CYAppContainer.shared.alertManager
myAlert.showWarning("自定义警告")
```

### 认证服务

```swift
let auth = CYAppContainer.shared.authService

// 登录（Mock 实现，自动持久化到 Keychain）
let user = try await auth.login(username: "john", password: "123")

// 刷新 Token
let newToken = try await auth.refreshToken(refreshToken)

// 登出（清除内存 + Keychain）
try await auth.logout()

// App 启动时恢复会话
if let user = await auth.restoreSession() {
    print("已恢复登录: \(user.name)")
}
```

### 分析服务

```swift
let analytics = CYAppContainer.shared.analyticsService

// 上报事件
analytics.track(event: "purchase", properties: ["amount": 29.9, "item": "pro_plan"])

// 用户识别
analytics.identify(userId: "12345", traits: ["plan": "pro"])

// 页面浏览追踪
analytics.trackScreen("Settings", category: "profile")

// 批量发送（可选，框架按需调用）
analytics.flush()
```

### 权限请求

```swift
let status = await CYPermissionManager.shared.request(.camera)
if status == .granted {
    // 打开相机
}
```

### 缓存

```swift
let cache = CYCacheManager.shared
await cache.save(value: token, forKey: "access_token", namespace: "Auth")
let token: String? = await cache.load(forKey: "access_token", namespace: "Auth")
await cache.remove(forKey: "access_token", namespace: "Auth")
```

### Keychain 安全存储

```swift
CYKeychainHelper.standard.save(refreshToken, service: "com.app.auth", account: "refresh_token")
let token = CYKeychainHelper.standard.readString(service: "com.app.auth", account: "refresh_token")
CYKeychainHelper.standard.delete(service: "com.app.auth", account: "refresh_token")
```

### 反馈样式自定义

```swift
// 启动时全局配置
CYFeedbackConfiguration.configure(
    toastStyle: CYToastStyle(
        position: .bottom,
        cornerRadius: 16,
        backgroundColor: .indigo,
        textColor: .white,
        iconColorStrategy: .fixed(.yellow)
    ),
    loadingStyle: CYLoadingStyle(
        maskOpacity: 0.3,
        cornerRadius: 20,
        indicatorColor: .mint
    )
)
```

---

## 常见问题

### Q: 如何处理不同后端的业务码规则？

在 App 启动时配置：

```swift
CYBusinessCodePolicy.configure {
    $0.successCodes = [0, 200, 1000]
    $0.tokenExpiredCodes = [401, 10001]
    $0.needReLoginCodes = [403, 10003]
    $0.displayMode = .toast
}
```

### Q: 如何 Mock 网络请求进行测试？

使用 Factory DI 注册 Mock 实现：

```swift
import FactoryKit

Container.shared.networkClient.register {
    MockNetworkClient()
}

struct MockNetworkClient: CYNetworkClientProtocol {
    func request<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> T {
        return mockUser as! T
    }
}
```

### Q: 如何替换 Toast/Loading/Alert 管理器？

在 App 启动时注册自定义实现：

```swift
Container.shared.toastManager.register {
    MyCustomToastManager()
}

struct MyCustomToastManager: CYToastManagerProtocol {
    // 实现协议方法
}
```

视图层传入自定义管理器：

```swift
ContentView()
    .feedbackOverlay(toastManager: myToast, loadingManager: myLoading)
    .alertManager(manager: myAlert)
```

### Q: 能否直接使用 Alamofire 的高级功能？

可以。虽然模板封装了 `CYNetworkClient`，但你仍可在业务代码中直接 `import Alamofire` 使用原生 API。

---

## 项目特异化指南

模板通过 **协议 + DI** 实现全部可替换。以下展示如何在消费项目中对各模块进行特异化处理，无需修改模板源码。

### 网络层特异化

**场景：替换为自定义加密网络客户端**

```swift
// 1. 实现协议
final class EncryptedNetworkClient: CYNetworkClientProtocol {
    // 包装 Alamofire 或自定义 URLSession
}

// 2. 注册到 DI（App 启动时）
Container.shared.networkClient.register { EncryptedNetworkClient() }
```

### 主题特异化

**场景：云端同步主题偏好**

```swift
// 1. 实现 CYThemeManaging 协议
final class CloudThemeManager: CYThemeManaging {
    func savedTheme() -> CYAppTheme {
        // 从服务端读取
    }
    func save(_ theme: CYAppTheme) {
        // 同步到服务端 + 本地缓存
    }
    func apply(_ theme: CYAppTheme) { /* UIKit overlay */ }
}

// 2. 注册到 DI
Container.shared.themeManager.register { CloudThemeManager() }

// 3. 创建 AppState 时注入
@State private var appState = CYAppState(
    themeManager: CYAppContainer.shared.themeManager
)
```

### 多语言特异化

**场景：服务端下发翻译**

```swift
// 1. 实现 CYLocalizationManaging 协议
final class RemoteLocalizationManager: CYLocalizationManaging {
    private var translations: [String: [String: String]] = [:]
    // ...
}

// 2. 注册到 DI
Container.shared.localizationManager.register { RemoteLocalizationManager() }

// 3. 注入 AppState
@State private var appState = CYAppState(
    localizationManager: CYAppContainer.shared.localizationManager
)
```

### 主题色彩特异化

```swift
// 直接覆盖静态颜色定义（App 启动时）
AppColors.primary = .indigo
AppColors.accent = .mint
AppColors.background = Color(uiColor: .systemGroupedBackground)
```

### Toast/Loading/Alert 特异化

**方式一：全局反馈样式配置**

```swift
CYFeedbackConfiguration.configure(
    toastStyle: CYToastStyle(
        position: .bottom,
        cornerRadius: 16,
        backgroundColor: .indigo,
        textColor: .white,
        iconColorStrategy: .fixed(.yellow)
    ),
    loadingStyle: CYLoadingStyle(
        maskOpacity: 0.3,
        cornerRadius: 20,
        indicatorColor: .mint
    )
)
```

**方式二：替换管理器实现**

```swift
// 注册自定义管理器
Container.shared.toastManager.register { MyCustomToastManager() }

// 视图层传入自定义实例
ContentView()
    .feedbackOverlay(
        toastManager: CYAppContainer.shared.toastManager,
        loadingManager: CYAppContainer.shared.loadingManager
    )
    .alertManager(manager: CYAppContainer.shared.alertManager)
```

### 业务码策略特异化

```swift
CYBusinessCodePolicy.configure {
    $0.successCodes = [0, 200, 1000]
    $0.tokenExpiredCodes = [401, 10001]
    $0.needReLoginCodes = [403]
    $0.silentCodes = [20005]  // 静默忽略的错误码
    $0.displayMode = .toast
}
```

### 测试中 Mock 注入

模板提供了全套 Mock 实现（`CYAppCore/Mock/`），直接使用：

```swift
// 替换所有关键组件为 Mock
Container.shared.networkClient.register { MockNetworkClient() }
Container.shared.authService.register { MockAuthService(userSession: CYUserSession()) }
Container.shared.analyticsService.register { MockAnalyticsService() }
Container.shared.toastManager.register { MockToastManager() }
Container.shared.loadingManager.register { MockLoadingManager() }
```

### 特异化层级总结

| 层级 | 入口 | 适用场景 |
|------|------|---------|
| 零代码配置 | `.configure(...)` | 切换环境、样式、业务码 |
| 协议实现 | 实现 `*Protocol` + DI 注册 | 替换网络、认证、分析、管理器 |
| 注入实例 | AppState init 参数 | 替换主题/语言管理策略 |
| 静态覆盖 | `AppColors.*` / `AppFonts.*` | 品牌色/字体定制 |

---

## 项目结构

```
CYSwiftTemplate/
├── Package.swift                  # SPM 配置（4 个 library + 1 个 executable）
├── .swiftlint.yml                 # 代码风格配置
├── .github/workflows/
│   └── ci.yml                     # CI（build + test + lint）
├── Sources/
│   ├── CYAppCore/                   # Layer 0: 纯逻辑层（无 SwiftUI）
│   │   ├── Base/                  #   AppError, AppTab, AppTheme, BaseViewModel, PaginatedListViewModel
│   │   ├── Network/               #   NetworkClient, APIResponse, BusinessCode, 拦截器, 请求去重
│   │   ├── Configuration/         #   AppConfiguration, AppEnvironment
│   │   ├── DI/                    #   DI 三件套 (Protocol + Factory + Facade)
│   │   ├── Services/              #   AuthService, AnalyticsService, UserSession
│   │   ├── Cache/                 #   CacheManager (Actor隔离, TTL支持)
│   │   ├── Persistence/           #   SwiftData 持久化
│   │   ├── Permissions/           #   相机/相册/定位/通知权限
│   │   ├── Managers/              #   Toast/Loading/Alert 管理器 (协议 + DI)
│   │   ├── Mock/                  #   MockNetworkClient, MockAuthService 等（5 个 Mock 类）
│   │   ├── Logger/                #   多级日志
│   │   └── Extensions/            #   10 个扩展文件
│   ├── CYFeedbackStyle/            # Layer 0 UI: Toast/Loading 样式定义
│   │   └── FeedbackConfiguration  #   CYToastStyle, CYLoadingStyle, CYFeedbackConfiguration
│   ├── CYAppDesignSystem/          # Layer 1: SwiftUI 设计系统
│   │   ├── Theme/                 #   AppColors, AppFonts, AppDimens, Color扩展
│   │   └── Components/            #   BaseView, Buttons, Cards, Shimmer, PaginatedList
│   ├── CYAppUI/                    # Layer 2: SwiftUI 功能组件
│   │   ├── AppState.swift         #   全局状态（可注入 ThemeManager/LocalizationManager）
│   │   ├── Router/                #   AppRouter (多Tab NavigationStack + Sheet)
│   │   ├── Managers/              #   ToastView, LoadingOverlay, AlertManagerView
│   │   ├── Onboarding/            #   引导页
│   │   └── Extensions/            #   6 个 View/Animation/EdgeInsets 扩展
│   ├── CYAppPersistence/           # Layer 3: SwiftData 持久化（独立、可选）
│   │   ├── BookmarkItem.swift     #   @Model 示例
│   │   ├── BookmarkRepository.swift # Repository 实现
│   │   ├── PersistenceController.swift # ModelContainer 管理
│   │   └── RepositoryProtocol.swift  # CRUD 协议
│   ├── CYAppCoreTests/             # Core 层单元测试 (50+ 用例)
│   ├── CYAppUITests/               # UI 层测试 (Router + AppState + Feedback)
│   ├── CYAppDesignSystemTests/     # 设计系统测试
│   └── CYFeedbackStyleTests/       # 反馈样式测试
└── ExampleApp/                     # 可运行 Demo
    └── Sources/
        └── ExampleApp.swift        # 3 Tab 示例
```

---

## 网络框架评估

### 核心优势

1. **类型安全**：编译时检查，Codable 替代 MJExtension 运行时反射
2. **业务码可配置**：避免全局硬编码 `code == 0`
3. **Token 自动刷新**：Actor 隔离并发安全，HTTP 401 + 业务码双链路
4. **请求去重**：Actor 隔离，防止快速点击
5. **协议驱动**：易测试、易扩展，不强依赖具体实现

### 功能覆盖

| GET/POST/PUT/DELETE | 文件上传/下载 | 业务码统一处理 |
| Token 自动刷新 | 401 自动重放 | 请求去重 |
| 离线检测 | 超时配置 | 请求/响应拦截器 |

### 对比主流方案

| 维度 | 本模板 | Alamofire | Moya |
|------|--------|-----------|------|
| 业务码处理 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Token 刷新 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 请求去重 | ⭐⭐⭐⭐⭐ | - | - |
| Mock 测试 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| 学习曲线 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

---

## 联系与贡献

- GitHub: https://github.com/your-org/CYSwiftTemplate
- Issues: https://github.com/your-org/CYSwiftTemplate/issues
- Pull Requests: 欢迎提交改进建议
