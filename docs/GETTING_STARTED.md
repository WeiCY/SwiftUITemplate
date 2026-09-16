# 完整接入指南

> 本文档涵盖从零接入到各模块使用的完整说明。如果只需 5 分钟快速预览，请先阅读 [README](../README.md)。

---

## 目录

- [1. 集成到项目](#1-集成到项目)
- [2. 启动配置](#2-启动配置)
- [3. 核心默认值配置](#3-核心默认值配置)
- [4. 多环境配置](#4-多环境配置)
- [5. 网络请求](#5-网络请求)
- [6. 高级网络功能](#6-高级网络功能)
- [7. 模型与解析](#7-模型与解析替代-mjextension)
- [8. 状态管理](#8-状态管理)
- [9. 导航路由](#9-导航路由)
- [10. 缓存](#10-缓存)
- [11. Keychain 安全存储](#11-keychain-安全存储)
- [12. 宿主认证](#12-宿主认证)
- [13. 反馈样式自定义](#13-反馈样式自定义)
- [14. 组件速查](#14-组件速查)
- [15. 常见问题](#15-常见问题)
- [16. 项目特异化指南](#16-项目特异化指南)
- [17. 模板开发规范](#17-模板开发规范)

---

## 1. 集成到项目

在 Xcode 中选择 **File → Add Package Dependencies**，输入仓库地址：

```
https://github.com/your-org/CYSwiftTemplate
```

按需引入以下 7 个库：

| 库名 | 用途 | 何时引入 |
|---|---|---|
| `CYAppCore` | 协议、扩展、日志、DI、管理器、权限 | **必选** |
| `CYAppNetwork` | Alamofire 网络实现（可选） | 需要 HTTP 请求时引入 |
| `CYAppImage` | Kingfisher 图片加载（可选） | 需要远程图片时引入 |
| `CYFeedbackStyle` | Toast/Loading 样式定义 | 有 UI 反馈时引入 |
| `CYAppDesignSystem` | 颜色、字体、间距、基础组件 | 有 UI 时引入 |
| `CYAppUI` | 路由、AppState、Toast 视图、Loading 视图、引导页 | 有 UI 时引入 |
| `CYAppPersistence` | SwiftData 持久化（可选） | 需本地存储时引入 |

### 推荐接入组合

为了让新项目更快落地，建议按下面的组合开始，而不是一开始把所有模块都加满。

#### 组合 A：个人项目最小闭环

适合：先把首页、主题、路由、反馈和基础 UI 跑起来。

- `CYAppCore`
- `CYFeedbackStyle`
- `CYAppDesignSystem`
- `CYAppUI`

可选再加：
- `CYAppNetwork`（需要接口时再加）
- `CYAppImage`（需要远程图片时再加）
- `CYAppPersistence`（需要本地数据时再加）

#### 组合 B：标准业务项目

适合：有列表、详情、登录、设置和网络请求的常规 App。

- `CYAppCore`
- `CYFeedbackStyle`
- `CYAppDesignSystem`
- `CYAppUI`
- `CYAppNetwork`

按需再加：
- `CYAppImage`
- `CYAppPersistence`

#### 组合 C：图片 / 内容密集型项目

适合：Feed 流、图文内容、头像和素材较多的项目。

- `CYAppCore`
- `CYFeedbackStyle`
- `CYAppDesignSystem`
- `CYAppUI`
- `CYAppNetwork`
- `CYAppImage`

#### 组合 D：带本地数据能力的项目

适合：收藏、书签、离线缓存、草稿箱、阅读记录等场景。

- `CYAppCore`
- `CYFeedbackStyle`
- `CYAppDesignSystem`
- `CYAppUI`
- `CYAppNetwork`
- `CYAppPersistence`

---

## 2. 启动配置

推荐在宿主 App 的 `AppConfig` / `AppBootstrap` 中配置，**不需要修改模板源码**。
`App.swift` 只负责调用 Bootstrap 和挂载根状态。下面是直接调用现有 API 的兼容写法；
新 App 建议参考 `ExampleApp/Sources/AppBootstrap.swift` 集中编排这些调用：

```swift
import SwiftUI
import CYAppCore
import CYAppNetwork
import CYFeedbackStyle
import CYAppUI

@main
struct MyApp: App {
    init() {
        // 1. 配置环境与网络请求
        CYNetworkConfiguration.configure(
            environment: .production,
            baseURL: "https://api.your-domain.com",
            defaultHeaders: [
                "X-App-Platform": "iOS",
                "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            ],
            timeoutInterval: 30
        )

        // 2. 配置业务状态码策略
        CYBusinessCodePolicy.configure {
            $0.successCodes = [0, 200]
            $0.tokenExpiredCodes = [401, 10001]
            $0.needReLoginCodes = [403]
            $0.displayMode = .toast
        }

        // 3. 配置全局反馈样式
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

> 启动顺序由宿主 `AppBootstrap` 统一编排。离线 App 只配置 Core；网络 App 再调用 `CYNetworkConfiguration.configure(...)`。网络配置重复调用会触发 `precondition`。

### 推荐启动顺序

为了让行为更统一，建议按下面顺序初始化：

1. `CYAppConstants.configure(...)`：覆盖缓存目录、Keychain service、分页等默认值
2. `CYNetworkConfiguration.configure(...)`：仅网络 App 注册网络客户端
3. `CYBusinessCodePolicy.configure { ... }`：统一业务码规则
4. `CYFeedbackConfiguration.configure(...)`：统一反馈样式
5. 如有需要，再注册自定义 DI 实现

这样可以保证默认值、网络层和 UI 层都在 App 启动阶段一次性准备好。

---

## 3. 核心默认值配置

在启动阶段、创建缓存或宿主账号服务之前，可覆盖模板默认的缓存目录、Keychain service 与分页设置：

```swift
CYAppConstants.configure(CYAppConfigurationValues(
    cacheDirectoryName: "MyAppCache",
    keychainService: "com.example.myapp.auth",
    defaultPageSize: 30
))
```

支持的配置项包括：缓存目录名、Keychain service、默认分页大小、Toast 默认时长、上传大小限制（超限上传会被 `CYNetworkClient.upload` 直接拒绝）等。

---

## 4. 多环境配置

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

CYNetworkConfiguration.configure(
    environment: .production,
    baseURL: baseURL,
    defaultHeaders: ["X-App-Platform": "iOS"]
)
```

---

## 5. 网络请求

> 完整、权威的网络层使用说明（请求 API、响应策略、业务码、可选凭证、上传下载、去重与 Mock）请阅读 [docs/NETWORK_GUIDE.md](NETWORK_GUIDE.md)。本节为快速上手。

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
let updatedUser: User = try await networkClient.request(UserEndpoint.update, body: body)

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
                .request(UserEndpoint.update, body: body)
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

## 6. 高级网络功能

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
CYNetworkConfiguration.configure(
    environment: .production,
    baseURL: "https://api.example.com",
    requestInterceptors: [
        EncryptionInterceptor(),
        CYLoggingInterceptor()
    ]
)
```

内置拦截器：`CYLoggingInterceptor`、`CYCredentialInterceptor`、`CYAuthenticationFailureInterceptor`。凭证格式和失败后的账号状态处理由宿主 App 决定。

### 请求去重

```swift
let deduplicator = CYAppContainer.shared.requestDeduplicator

// 相同 key 的并发请求自动合并，只发起一次网络请求
let user: User = try await networkClient.requestWithDeduplication(
    UserEndpoint.profile,
    deduplicator: deduplicator
)

// POST：Encodable body 会纳入去重键（相同 body 合并，不同 body 不误合并）
let updated: User = try await networkClient.requestWithDeduplication(
    UserEndpoint.update,
    body: UpdateRequest(name: "Tom"),
    deduplicator: deduplicator
)
```

### 响应策略 send（envelope / direct / raw / empty）

```swift
// envelope：默认包装，自动解包 data（等价 request）
let user: User = try await networkClient.send(UserEndpoint.profile, strategy: .envelope)

// envelopeRaw：返回原始 CYAPIResponse，不按业务码抛错（等价 requestRaw）
let response: CYAPIResponse<User> = try await networkClient.send(UserEndpoint.profile, strategy: .envelopeRaw)

// direct：响应体直接就是目标类型（无 envelope，适合第三方接口）
let raw: ThirdPartyDTO = try await networkClient.send(OpenAPIEndpoint.status, strategy: .direct)

// empty：只关心成功与否（204 等空响应）
let _: CYEmptyResponse = try await networkClient.send(UserEndpoint.delete, strategy: .empty)
```

### 便捷 API（requestVoid / requestData / request(body:)）

```swift
// 只确认成功（业务错误仍会抛出）
try await networkClient.requestVoid(UserEndpoint.delete(id: 123))

// 原始响应体 Data（图片、文件等二进制）
let imageData: Data = try await networkClient.requestData(ImageEndpoint.fetch)

// 泛型 Encodable body（等价 post）
let user: User = try await networkClient.request(AuthEndpoint.login, body: LoginRequest(...))
```

### 空响应 / 204（CYEmptyResponse）

POST / DELETE 等只返回 `code + message`（或 204 No Content）的接口，用 `CYEmptyResponse`：

```swift
let _: CYEmptyResponse = try await networkClient.request(UserEndpoint.delete(id: 123))
// 204 空 body、缺 data 键、data 为 null 均视为成功
```

### 文件上传（单文件 / 多文件 / 进度）

```swift
let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()

// 单文件
let avatar: Avatar = try await networkClient.upload(
    UserEndpoint.uploadAvatar,
    parts: [
        CYMultipartPart(data: imageData, mimeType: "image/jpeg", fileName: "avatar.jpg", paramName: "file")
    ],
    additionalParams: ["user_id": "123"]
)

// 多文件 + 进度回调（fractionCompleted ∈ [0, 1]）
let result: UploadResult = try await networkClient.upload(
    UserEndpoint.uploadAttachments,
    parts: [
        CYMultipartPart(data: imageData, mimeType: "image/jpeg", fileName: "a.jpg", paramName: "avatar"),
        CYMultipartPart(data: coverData, mimeType: "image/png", fileName: "c.png", paramName: "cover"),
    ],
    additionalParams: ["scene": "profile"],
    progress: { fraction in
        uploadProgressView.progress = fraction
    }
)
```

> 超过 `CYAppConstants.maxUploadSizeMB` 设置的上限时，上传会在发起请求前被拒绝并抛出 `CYNetworkError.payloadTooLarge`。

### 文件下载（进度 / 取消）

```swift
let fileURL = try await networkClient.download(
    FileEndpoint.downloadPDF(id: "doc123"),
    to: documentsDirectory.appendingPathComponent("doc.pdf"),
    progress: { fraction in
        downloadProgressView.progress = fraction
    }
)

// 取消会传播到底层请求，Task 取消时抛出 CYNetworkError.cancelled
let task = Task { try await networkClient.download(...) }
task.cancel()
```

### 可选凭证与恢复

端点通过 `authentication` 声明 `.none`、`.optional` 或 `.required`，默认 `.none`。只有 `.required` 请求认证失败时，才会调用宿主注册的 `CYCredentialRecovery`；并发失败共享一次恢复，成功后最多重放一次。Network 不判断登录状态，也不持有 User、Access Token 或 Refresh Token 模型。

### 日志脱敏

`CYLoggingInterceptor` 自动对敏感信息脱敏：

- 请求头：`Authorization`、`Cookie`、`X-Api-Key`、`Token` 等值输出为 `***`
- 请求/响应体：`password`、`token`、`access_token`、`refresh_token`、`secret` 等字段值输出为 `***`

```swift
// 开启网络日志
CYNetworkConfiguration.configure(
    environment: .production,
    baseURL: "https://api.example.com",
    requestInterceptors: [CYLoggingInterceptor()]   // includeBody: false 可关闭 Body 打印
)
```

---

## 7. 模型与解析（替代 MJExtension）

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
    let avatar: String?     // 可选 - 后端可能不返回
    let bio: String?        // 可选
}
```

`JSONDecoder` 自动处理缺失字段和嵌套结构的递归解析。

---

## 8. 状态管理

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
| 主题偏好 / 语言 | 搜索关键词 |
| App 生命周期通用偏好 | 页面列表数据 / loading / error |

---

## 9. 导航路由

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
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab.id)) {
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
        .onChange(of: selectedTab) { _, tab in router.selectTab(tab.id) }
        .feedbackOverlay()
    }
}
```

---

## 10. 缓存

`CYCacheManager` 是 Actor 隔离的内存 + 磁盘缓存，支持 TTL 过期。

```swift
let cache = CYCacheManager.shared

// 写入（返回 Result，可感知失败）
let saveResult = await cache.save(value: token, forKey: "access_token", namespace: "Auth")
if case .failure(let error) = saveResult { print(error.localizedDescription) }

// 读取
let token: String? = await cache.load(forKey: "access_token", namespace: "Auth")

// 删除
let removeResult = await cache.remove(forKey: "access_token", namespace: "Auth")
```

缓存目录名可通过 `CYAppConstants.configure(...)` 自定义。

---

## 11. Keychain 安全存储

```swift
let result = CYKeychainHelper.standard.save(
    refreshToken,
    service: "com.app.auth",
    account: "refresh_token",
    accessibility: .afterFirstUnlock
)
if case .failure(let error) = result {
    // 上报、重试或提示用户
    print(error.localizedDescription)
}

let token = try? CYKeychainHelper.standard
    .readStringResult(service: "com.app.auth", account: "refresh_token")
    .get()

let deleteResult = CYKeychainHelper.standard.delete(service: "com.app.auth", account: "refresh_token")
```

Keychain service 默认值可通过 `CYAppConstants.configure(...)` 统一覆盖。

---

## 12. 宿主认证

```swift
let credential = CYCredentialInterceptor {
    await accountStore.authorizationHeader // 例如 "Bearer ..." 或自定义格式
}
networkClient.addRequestInterceptor(credential)
networkClient.setCredentialRecovery(CYCredentialRecovery(action: {
    try await accountStore.refreshCredential()
}))
```

模板不提供 User、登录状态或 AuthService。需要账号的宿主 App 自行拥有这些模型；无需账号的 App 不做任何认证配置。

---

## 13. 反馈样式自定义

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

## 14. 组件速查

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

---

## 15. 常见问题

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

## 16. 项目特异化指南

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

## 17. 模板开发规范

如果你要在这个模板上持续做个人或中小团队项目，建议先阅读并遵守 [模板开发规范](TEMPLATE_RULES.md)。

它会明确：

- 这套模板适合什么场景
- 哪些模块是必选、推荐、可选
- 如何保持快速接入
- 代码、文档、示例和测试应遵守什么规则
- 模板目录结构应如何保持稳定

这份规范的目标是让模板长期保持“好起步、好维护、好扩展”的状态。

---

## 18. iOS 18+ 推荐页面范式

随着模板进入 iOS 18+ SwiftUI 项目标准，建议业务页面优先使用以下范式，而不是每个页面都自行拼装结构。

### 18.1 页面优先级

推荐优先使用：

- `CYPageContainer`：标准页面容器，统一标题、内容、工具栏布局
- `CYBaseView`：统一加载 / 错误 / 内容三态
- `CYEmptyStateView`：统一空状态
- `CYPaginatedListView`：统一分页列表
- `CYLoadingOverlay`、`CYToastView`、`CYAlertManagerModifier`：统一反馈层

### 18.2 页面类型映射

#### 列表页

优先组合：

- `CYPageContainer`
- `CYPaginatedListView`
- `CYEmptyStateView`
- `CYLoadingOverlay`

#### 详情页

优先组合：

- `CYPageContainer`
- `CYBaseView`
- `CYLoadingOverlay`
- `CYToastView`

#### 设置页

优先组合：

- `CYPageContainer`
- `CYListRow`
- `CYSectionHeader`
- `CYTagGroup`
- `CYBottomSheetModifier`

#### 表单页

优先组合：

- `CYPageContainer`
- `CYTextField`
- `CYSearchBar`
- `CYVerificationCodeInput`
- `PrimaryButton` / `SecondaryButton`

### 18.3 现代 SwiftUI 使用建议

- 页面优先使用 `@Observable` 状态模型
- 顶层状态优先通过 `@Environment(CYAppState.self)` 注入
- 列表页优先使用 `refreshable` 和分页加载
- 输入页优先使用键盘可感知布局
- 需要更复杂多栏布局时，再逐步引入 `NavigationSplitView`

这部分范式的目标是：让新项目从一开始就贴近 iOS 18+ 的 SwiftUI 体验，而不是自己重复搭一套页面壳。
