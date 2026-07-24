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

### 2. 配置环境与网络

在 `@main App` 初始化时配置，**不需要修改模板源码**：

```swift
import SwiftUI
import CYAppCore
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
    }
    
    @State private var appState = CYAppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
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
let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as! String

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
// 获取网络客户端（使用启动时配置的实例）
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
switch response.businessResult {
case .success:
    let user = response.data
case .tokenExpired:
    // 框架已自动刷新 Token，此处可选添加 UI 提示
case .businessError(_, let message, let display):
    if display == .alert { showAlert(message) }
    else { showToast(message) }
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

### 自定义请求拦截器（添加加密/签名）

```swift
import CYAppCore

struct EncryptionInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest) async {
        // 示例：对请求体加密
        if let body = request.httpBody {
            let encrypted = encrypt(body)
            request.httpBody = encrypted
            request.setValue("encrypted", forHTTPHeaderField: "X-Content-Encoding")
        }
    }
    
    private func encrypt(_ data: Data) -> Data {
        // 实现加密逻辑
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

### 配置 Token 自动刷新

```swift
// 在 App 启动后配置（需等待 CYAppConfiguration.configure 完成）
let networkClient = CYAppContainer.shared.networkClient as! CYNetworkClient

networkClient.setTokenRefreshInterceptor(
    CYTokenRefreshInterceptor(
        refreshTokenProvider: {
            // 返回当前 RefreshToken
            CYAppContainer.shared.userSession.refreshToken
        },
        refreshAction: { refreshToken in
            // 调用刷新接口
            let response: TokenResponse = try await networkClient.post(
                AuthEndpoint.refreshToken,
                body: ["refresh_token": refreshToken]
            )
            
            // 保存新 Token
            await CYAppContainer.shared.userSession.updateTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            
            return response.accessToken
        },
        onRefreshFailed: {
            // Token 刷新失败，跳转登录页
            await MainActor.run {
                CYAppRouter.shared.navigate(to: .login)
            }
        }
    )
)
```

### 请求去重（防止快速点击）

```swift
// 在 ViewModel 中使用去重器
let deduplicator = CYAppContainer.shared.requestDeduplicator

let user: User = try await deduplicator.request(
    UserEndpoint.profile,
    using: networkClient
)
// 500ms 内的重复请求会自动合并，只发起一次网络请求
```

### 文件上传

```swift
let imageData = image.jpegData(compressionQuality: 0.8)!

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
print("文件已下载到: \(fileURL)")
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

// 测试代码中
Container.shared.networkClient.register {
    MockNetworkClient()
}

struct MockNetworkClient: CYNetworkClientProtocol {
    func request<T: Decodable & Sendable>(_ endpoint: CYEndpoint) async throws -> T {
        // 返回测试数据
        return mockUser as! T
    }
}
```

### Q: 能否直接使用 Alamofire 的高级功能？

可以。虽然模板封装了 `CYNetworkClient`，但你仍可在业务代码中直接 `import Alamofire` 使用原生 API。

### Q: 如何实现请求签名？

实现自定义拦截器：

```swift
struct SignatureInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest) async {
        let timestamp = "\(Date().timeIntervalSince1970)"
        let signature = generateSignature(url: request.url!, timestamp: timestamp)
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
    }
}

// 在配置时注册
CYAppConfiguration.configure(
    environment: .production,
    baseURL: "https://api.example.com",
    requestInterceptors: [SignatureInterceptor()]
)
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
│   │   ├── Configuration/        #   AppConfiguration, AppEnvironment
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

---

## 网络框架评估

### 核心优势

1. **类型安全**：编译时检查，Codable 替代 MJExtension 运行时反射
2. **业务码可配置**：避免全局硬编码 `code == 0`
3. **Token 自动刷新**：并发安全，HTTP 401 + 业务码双链路
4. **请求去重**：Actor 隔离，防止快速点击
5. **协议驱动**：易测试、易扩展，不强依赖具体实现

### 功能覆盖

✅ GET/POST/PUT/DELETE  
✅ 文件上传/下载  
✅ 业务码统一处理  
✅ Token 自动刷新  
✅ 401 自动重放  
✅ 请求去重  
✅ 离线检测  
✅ 超时配置  
✅ 请求/响应拦截器  

### 对比主流方案

| 维度 | 本模板 | Alamofire | Moya |
|------|--------|-----------|------|
| 业务码处理 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Token 刷新 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 请求去重 | ⭐⭐⭐⭐⭐ | ❌ | ❌ |
| Mock 测试 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| 学习曲线 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

**推荐行动**：保持当前架构，符合大部分业务场景。

---

## 联系与贡献

- GitHub: https://github.com/your-org/CYSwiftTemplate
- Issues: https://github.com/your-org/CYSwiftTemplate/issues
- Pull Requests: 欢迎提交改进建议
