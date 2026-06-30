# CYSwiftTemplate 使用指南

## 快速开始

### 1. 集成到项目

在 Xcode 中选择 **File → Add Package Dependencies**，输入仓库地址：

```
https://github.com/your-org/CYSwiftTemplate
```

按需引入三个库：

| 库名 | 用途 | 何时引入 |
|---|---|---|
| `CYAppCore` | 网络、缓存、DI、状态管理 | **必选** |
| `CYAppDesignSystem` | 颜色、字体、间距、基础组件 | 有 UI 时引入 |
| `CYAppUI` | 路由、Toast、Loading、引导页 | 有 UI 时引入 |

### 2. App 入口

```swift
import SwiftUI
import CYAppCore
import CYAppUI

@main
struct MyApp: App {
    @State private var appState = CYAppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
```

### 3. 配置环境

编辑 `Sources/CYAppCore/Configuration/AppEnvironment.swift`，填入你的后端地址和配置：

```swift
public var baseURL: String {
    switch self {
    case .development:
        return "https://dev-api.example.com"
    case .staging:
        return "https://staging-api.example.com"
    case .production:
        return "https://api.example.com"
    }
}
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

    // GET 请求用 queryItems
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
// 响应模型 — 遵循 Decodable
struct User: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let avatar: String?
    let email: String?
}

// 请求模型 — 遵循 Encodable（用于 POST body）
struct UpdateProfileBody: Encodable, Sendable {
    let name: String
    let email: String
}
```

> **为什么用 `struct` 而不是 `NSObject`？**
> Swift 的 `Codable` 协议由编译器自动生成 JSON 解析代码，无需 MJExtension 等运行时反射库。
> 字段写错 → 编译报错，而非运行时崩溃。详见下方「模型与解析」章节。

### Step 3: 发起请求

```swift
// 获取网络客户端
let networkClient = CYAppContainer.shared.networkClient

// ─── 方式 1：自动解包（推荐，99% 场景）───
// 后端返回 {"code": 0, "data": {...}, "message": "ok"}
// 自动取出 data 部分的 User 对象
let user: User = try await networkClient.request(UserEndpoint.profile)

// ─── 方式 2：带 Encodable body 的 POST ───
let body = UpdateProfileBody(name: "John", email: "john@example.com")
let updatedUser: User = try await networkClient.post(UserEndpoint.update, body: body)

// ─── 方式 3：获取完整响应（需要手动处理业务码）───
let response: CYAPIResponse<User> = try await networkClient.requestRaw(UserEndpoint.profile)
if response.code == 10001 {
    // Token 过期，刷新后重试
} else if response.isSuccess {
    let user = response.data
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

### 拦截器（全局注入 Header / Token / 日志）

在 App 启动时注册拦截器：

```swift
let networkClient = CYNetworkClient.shared

// 日志拦截器 — 打印请求/响应详情
networkClient.addRequestInterceptor(CYLoggingInterceptor())
networkClient.addResponseInterceptor(CYLoggingInterceptor())

// Token 拦截器 — 自动注入 Authorization Header
networkClient.addRequestInterceptor(CYAuthInterceptor {
    CYAppContainer.shared.userSession.accessToken
})
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

### 基本用法

```swift
// 1. 定义模型
struct Product: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let price: Double
    let createdAt: String?
}

// 2. 网络请求自动解析（本模板已内置）
let products: [Product] = try await networkClient.request(ProductEndpoint.list)

// 3. 手动解析（测试 / 本地 JSON 场景）
let data = jsonString.data(using: .utf8)!
let product = try JSONDecoder().decode(Product.self, from: data)

// 4. 模型转 JSON
let body = UpdateProfileBody(name: "John", email: "john@test.com")
let jsonData = try JSONEncoder().encode(body)
```

### 字段名映射

如果后端用 `snake_case`（如 `created_at`），有两种处理方式：

```swift
// 方式 A：全局转换（推荐）
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

// 方式 B：手动映射
struct Product: Decodable {
    let id: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}
```

### 嵌套模型

```swift
struct OrderResponse: Decodable, Sendable {
    let order: Order
    let items: [OrderItem]
}

struct Order: Decodable, Sendable {
    let id: String
    let totalAmount: Double
    let status: String
}

struct OrderItem: Decodable, Sendable {
    let productId: Int
    let quantity: Int
    let unitPrice: Double
}

// 使用：嵌套结构自动递归解析，无需额外配置
let response: OrderResponse = try await networkClient.request(OrderEndpoint.detail(id: "123"))
```

### 可选字段

```swift
struct User: Decodable, Sendable {
    let id: Int
    let name: String
    let avatar: String?     // 可选 — 后端可能不返回
    let bio: String?        // 可选
}
```

用 `?` 标记即可，`JSONDecoder` 自动处理缺失字段。

---

## 状态管理

### CYAppState（全局状态）

跨页面共享的状态放 `CYAppState`：

```swift
// 任意 View 中读取
struct SettingsView: View {
    @Environment(CYAppState.self) private var appState

    var body: some View {
        @Bindable var state = appState  // 需要双向绑定时
        VStack {
            Text(appState.user?.name ?? "Guest")
            Picker("Theme", selection: $state.theme) {
                ForEach(CYAppTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
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
| 选中 Tab | 页面 loading / error |
| 主题偏好 | 搜索关键词 |
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
```

### 在 View 中使用

```swift
struct RootView: View {
    @Bindable var router = CYAppRouter.shared

    var body: some View {
        NavigationStack(path: $router.path) {
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
    }
}
```

---

## DI 依赖注入

### 获取依赖

```swift
// 方式 1：通过 Facade（推荐）
let client = CYAppContainer.shared.networkClient
let cache  = CYAppContainer.shared.cacheManager

// 方式 2：通过 Factory @Injected
import Factory

struct MyView: View {
    @Injected(\.networkClient) var networkClient
    ...
}
```

### 自定义注册

在 `Container.swift` 中添加你的 Service：

```swift
extension Container {
    var myService: Factory<MyServiceProtocol> {
        self { MyService() }
            .singleton
    }
}
```

---

## 组件速查

### Toast 提示

```swift
CYToastManager.shared.show("保存成功", type: .success)
CYToastManager.shared.show("网络错误", type: .error, duration: 3.0)
CYToastManager.shared.dismiss()
```

### Loading 遮罩

```swift
CYLoadingManager.shared.show()
// ... 执行操作 ...
CYLoadingManager.shared.hide()
```

### 权限请求

```swift
let granted = try await CYPermissionManager.shared.request(.camera)
if granted {
    // 打开相机
}
```

### 缓存

```swift
let cache = CYCacheManager.shared
cache.save(value: token, forKey: "access_token", namespace: "Auth")
let token: String? = cache.load(forKey: "access_token", namespace: "Auth")
cache.remove(forKey: "access_token", namespace: "Auth")
```

### Keychain 安全存储

```swift
CYKeychainHelper.save(key: "refresh_token", value: refreshToken)
let token = CYKeychainHelper.load(key: "refresh_token")
CYKeychainHelper.delete(key: "refresh_token")
```

---

## 项目结构

```
CYSwiftTemplate/
├── Package.swift                 # SPM 配置
├── Sources/
│   ├── CYAppCore/                  # Layer 0: 纯逻辑层（无 SwiftUI）
│   │   ├── Base/                 #   CYAppState, CYBaseViewModel, CYAppError, CYAppTab
│   │   ├── Network/              #   CYNetworkClient, CYAPIResponse, 拦截器
│   │   ├── DI/                   #   DI 三件套 (Factory + Protocol + Facade)
│   │   ├── Services/             #   CYAuthService, CYUserSession, CYAnalyticsService
│   │   ├── Cache/                #   CYCacheManager
│   │   ├── Persistence/          #   SwiftData 持久化
│   │   ├── Permissions/          #   相机/相册/定位/通知权限
│   │   └── ...
│   ├── CYAppDesignSystem/          # Layer 1: SwiftUI 设计系统
│   │   ├── Theme/                #   CYAppColor, CYAppFont, CYAppDimens
│   │   └── Components/           #   CYBaseView, ShimmerView, 通用组件
│   ├── CYAppUI/                    # Layer 2: SwiftUI 功能组件
│   │   ├── Router/               #   CYAppRouter 导航
│   │   ├── Managers/             #   CYToastView, CYLoadingOverlay
│   │   ├── Onboarding/           #   引导页
│   │   └── Extensions/           #   View 扩展
│   └── CYAppCoreTests/             # 单元测试
└── ExampleApp/                   # 入口示例
```
