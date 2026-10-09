# 架构设计

> 本文档描述 CYSwiftTemplate 的模块分层、依赖注入、状态管理、路由与网络架构，以及扩展方式。

---

## 目录

- [1. 设计原则](#1-设计原则)
- [2. 模块分层与依赖图](#2-模块分层与依赖图)
- [3. 各模块职责](#3-各模块职责)
- [4. 依赖注入（DI）](#4-依赖注入di)
- [5. 状态管理](#5-状态管理)
- [6. 路由系统](#6-路由系统)
- [7. 网络层架构](#7-网络层架构)
- [8. 反馈与 UI 覆盖层](#8-反馈与-ui-覆盖层)
- [9. 持久化层](#9-持久化层)
- [10. 并发模型](#10-并发模型)
- [11. 扩展方式](#11-扩展方式)
- [12. 项目目录结构](#12-项目目录结构)

---

## 1. 设计原则

### 启动配置与 Optional Module

Core 提供 `CYAppConfig` 和 `CYCoreBootstrap`，只处理 Core 能理解的基础配置。
宿主 App 负责作为 Composition Root 的 `AppBootstrap`，按需调用 Network、Image、
Feedback 等现有配置入口。Core 不反向依赖 Optional Module；完全离线的 App 可以不
引入 `CYAppNetwork`，需要网络的 App 再组合 `CYNetworkConfiguration`。

| 原则 | 实践 |
|---|---|
| **协议驱动** | 稳定基础能力以协议暴露：网络、分析、图片加载、反馈管理器、主题、多语言、权限、持久化 Repository |
| **按需引入** | 网络实现（Alamofire）、图片实现（Kingfisher）、持久化（SwiftData）均为独立 target，业务代码只依赖协议 |
| **DI 可替换** | 基于 Factory 的三层 DI 架构，任何服务都可在启动时或测试中替换 |
| **Swift 6 并发安全** | 全量 `Sendable`、`@MainActor`、`actor` 隔离，`OSAllocatedUnfairLock` / `NSLock` 保护非 actor 共享状态 |
| **零源码修改** | 所有特异化通过 `.configure(...)`、协议实现 + DI 注册、AppState 注入参数完成，不修改模板源码 |

---

## 2. 模块分层与依赖图

```
Layer 0 — 纯逻辑 / 实现层（无 SwiftUI）
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   CYAppCore ──────► FactoryKit                              │
│   (协议 + 工具 + DI)                                        │
│      ▲                                                      │
│      │                                                      │
│   ┌──┴──────────┬──────────────┐                           │
│   │             │              │                            │
│ CYAppNetwork  CYAppImage    CYFeedbackStyle                │
│ (+Alamofire)  (+Kingfisher)  (无依赖, 纯样式)                │
│   (+FactoryKit) (+FactoryKit)                               │
│                                                             │
│   CYAppPersistence (无依赖, 独立 SwiftData)                  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
Layer 1 — UI 基础
┌─────────────────────────────────────────────────────────────┐
│  CYAppDesignSystem ──► CYAppCore + CYFeedbackStyle          │
│  (颜色 / 字体 / 间距 / 基础组件)                              │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
Layer 2 — UI 功能
┌─────────────────────────────────────────────────────────────┐
│  CYAppUI ──► CYAppCore + CYFeedbackStyle + CYAppDesignSystem│
│  (AppState / Router / Toast 视图 / Loading 视图 / 引导页)    │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
                    ExampleApp（接入范例）
```

**关键规则**：`CYAppCore` 定义网络协议并提供 URLSession 图片加载默认实现；真正的网络客户端只由可选的 `CYAppNetwork` 注册。离线 App 不应访问 `networkClient`。

### 依赖矩阵

| Target | 依赖 |
|---|---|
| `CYAppCore` | FactoryKit |
| `CYAppNetwork` | CYAppCore, Alamofire, FactoryKit |
| `CYAppImage` | CYAppCore, Kingfisher, FactoryKit |
| `CYFeedbackStyle` | （无） |
| `CYAppDesignSystem` | CYAppCore, CYFeedbackStyle |
| `CYAppUI` | CYAppCore, CYFeedbackStyle, CYAppDesignSystem |
| `CYAppPersistence` | （无，独立） |
| `ExampleApp` | CYAppCore, CYAppNetwork, CYAppImage, CYFeedbackStyle, CYAppDesignSystem, CYAppUI, CYAppPersistence |

---

## 3. 各模块职责

### CYAppCore（Layer 0 — 核心骨架）

整个模板的基础，遵循 **协议驱动 + DI 注入** 的设计原则。

| 子目录 | 职责 | 关键类型 |
|---|---|---|
| `Network/` | 网络协议层 | `CYEndpoint`, `CYNetworkClientProtocol`, `CYAuthenticationPolicy`, `CYCredentialInterceptor`, `CYCredentialRecovery`, `CYRequestDeduplicator` |
| `Services/` | 通用服务 | `CYAnalyticsServiceProtocol` |
| `DI/` | 依赖注入 | `DIContainerProtocol`, `NetworkProviding`, `CYFactoryContainer`, `CYAppContainer` |
| `Configuration/` | 环境配置 | `CYAppEnvironment` |
| `Constants/` | 全局常量 | `CYAppConstants`, `CYAppConfigurationValues`, `CYSFSymbol` |
| `Cache/` | Actor 隔离缓存 | `CYCacheManager`, `CYCacheSerializer` |
| `Managers/` | 反馈管理器（协议 + 单例） | `CYToastManager`, `CYLoadingManager`, `CYAlertManager` |
| `Permissions/` | 权限管理 | `CYPermissionManager`, `CYPermissionType`, `CYPermissionRequester` |
| `Image/` | 图片加载协议 | `CYImageLoaderProtocol`, `CYDefaultImageLoader` |
| `Logger/` | 日志 | `CYLogger`, `CYLogLevel` |
| `Helpers/` | 工具类 | `CYKeychainHelper`, `CYBiometricAuth`, `CYFormValidator`, `CYDebouncer`, `CYThrottler`, `CYDeepLinkHandler`, `CYNetworkMonitor`, `CYThemeManager`, `CYLocalizationManager` |
| `Mock/` | 测试 Mock | `MockNetworkClient`, `MockAnalyticsService`, `MockToastManager`, `MockLoadingManager` |
| `Base/` | ViewModel 与基础状态 | `CYBaseViewModel`, `CYPaginatedListViewModel<Item>`, `CYAppError`, `CYTabID`, `CYAppTheme` |
| `Extensions/` | Foundation 扩展 | Collection, String, Date, Data, Optional, Numeric, Dictionary, Bundle 等 16 个文件 |

### CYAppNetwork（Layer 0 — 网络实现）

Alamofire 桥接层，按职责拆分为多个文件：

| 文件 | 职责 |
|---|---|
| `AppConfiguration.swift` | `CYNetworkConfiguration` — 启动配置器，构建 `CYNetworkClient` 并注册到 Factory |
| `Network/NetworkClient.swift` | `CYNetworkClient` 类核心：`Mutex` 可变状态、拦截器管理、凭证恢复、`send` 分发 |
| `Network/NetworkClient+Request.swift` | URL/URLRequest 构建、JSON 编解码器、请求/响应拦截器应用、失败日志 |
| `Network/NetworkClient+Response.swift` | 发送/解码、业务码解析、Alamofire 错误映射、`requestData` |
| `Network/NetworkClient+Upload.swift` | 多文件上传与下载（进度回调、取消传播） |

`CYNetworkClient` 的可变状态（拦截器、刷新协调器）由 `Mutex`（iOS 18 `Synchronization`）保护，类型满足 `Sendable`，不使用 `@unchecked Sendable`。请求去重便捷 API（`requestWithDeduplication`）定义在 `CYAppCore` 的 `CYNetworkClientProtocol` 扩展上，因此生产客户端与 `MockNetworkClient` 均可使用。

### CYAppImage（Layer 0 — 图片实现）

Kingfisher 桥接层。

| 文件 | 职责 |
|---|---|
| `ImageLoader.swift` | `CYAppImageConfig`（注册 Kingfisher 到 DI）、`CYKingfisherImageLoader`（实现 `CYImageLoaderProtocol`） |

### CYFeedbackStyle（Layer 0 — 反馈样式）

无依赖的纯样式定义模块。

| 类型 | 职责 |
|---|---|
| `CYToastStyle` | Toast 位置、圆角、颜色、图标策略 |
| `CYLoadingStyle` | Loading 遮罩透明度、指示器颜色、圆角 |
| `CYErrorStyle` | 错误视图样式 |
| `CYFeedbackConfiguration` | `@Observable` 全局样式持有者，`.configure(...)` 入口 |

### CYAppDesignSystem（Layer 1 — 设计系统）

| 子目录 | 关键类型 |
|---|---|
| `Theme/` | `CYAppColor`（品牌色可经 `CYAppColor.configure(primary:accent:)` 零源码覆盖）、`CYAppFont`、`CYAppDimens`、Color+Hex 扩展 |
| `Components/` | `CYBaseView`, `CYLoadingIndicator`, `PrimaryButton`/`SecondaryButton`/`CYScaledButtonStyle`, `CardView`（可定制内边距/圆角/背景/阴影）, `CYEmptyStateView`, `CYTextField`/`CYSearchBar`/`CYVerificationCodeInput`, `CYListRow`/`CYSectionHeader`, `CYPaginatedListView`, `CYBadge`/`CYTag`/`CYFlowLayout`, `ShimmerModifier`/`SkeletonRow`, `CYBottomSheetModifier`/`CYSnackBar` |

### CYAppUI（Layer 2 — UI 功能）

| 子目录 | 关键类型 |
|---|---|
| `AppState.swift` | `CYAppState` — 全局状态容器 |
| `Router/` | `CYAppRouter` — 多 Tab NavigationStack 路由 |
| `Managers/` | `CYToastView`, `CYLoadingOverlay`, `CYAlertManagerModifier` |
| `Extensions/` | `.feedbackOverlay()`, `.toastView()`, `.loadingOverlay()`, `.alertManager()`, `.snackBar()`, `.cyBottomSheet()` |
| `Onboarding/` | `CYOnboardingView`, `CYOnboardingPage` |
| `Components/` | `CYMediaPicker`, `CYShareSheet` |
| `Image/` | `CYRemoteImageView` |
| `Helpers/` | `CYKeyboardObserver` |

### CYAppPersistence（独立 — SwiftData）

| 文件 | 关键类型 |
|---|---|
| `PersistenceController.swift` | `CYPersistenceController` — 根据宿主模型创建 ModelContainer |
| `RepositoryProtocol.swift` | `CYRepositoryProtocol` — 泛型 CRUD 协议 |

Bookmark/Tag 模型和 Repository 位于 `ExampleApp`，不属于通用 Persistence。

---

## 4. 依赖注入（DI）

### 三层架构

```
DIContainerProtocol          ← 基础能力抽象（11 个服务 getter，不含网络）
NetworkProviding             ← 可选网络能力抽象（networkClient）
       ▲
       │ implements both
       │
CYFactoryContainer           ← Factory 实现（注册 Factory<T>）
       ▲
       │ delegates
       │
CYAppContainer               ← Legacy Facade（保持向后兼容，逐步由注入替代）
```

- `DIContainerProtocol` = 基础能力（11 个服务 getter，不含网络）
- `NetworkProviding` = 可选网络能力（`networkClient`）
- `CYFactoryContainer` = Factory 实现（注册 `Factory<T>`）
- `CYAppContainer` = Legacy / Compatibility Facade

> 原则：新 Feature 优先使用**初始化注入**；全局容器应尽量只出现在 Composition Root 或兼容代码中。

### 能力拆分（Base DI vs Network Capability）

`DIContainerProtocol` 不包含 `networkClient`。只有需要网络的 Feature 才声明组合依赖：

```swift
// 网络 Feature：编译期要求网络能力
final class HomeViewModel: CYBaseViewModel {
    private let dependencies: any DIContainerProtocol & NetworkProviding
}

// 离线 Feature：只依赖基础能力，不感知网络层
final class NoteViewModel: CYBaseViewModel {
    private let dependencies: any DIContainerProtocol
}
```

这样离线 App 不会被基础 DI 契约强迫提供网络能力；网络 Feature 又能获得编译期保证。

### Composition Root（组合根）

`ExampleApp` 采用如下组织方式（模板不新增额外框架类型，只是当前设计的说明）：

```
App
 ↓
AppBootstrap         配置环境 / 网络 / 反馈（框架级）
 ↓
AppDependencies      构造 Service / Repository / ViewModel（业务级）
 ↓
ViewModel / Service / Repository
 ↓
Feature
```

`AppBootstrap` 负责框架配置，`AppDependencies` 负责业务依赖构造并显式注入；Feature View 只接收已构造好的 ViewModel。完整示例见 `ExampleApp/Sources/App/AppDependencies.swift`。

### 服务注册

| 服务 | 默认实现 | 生命周期 |
|---|---|---|
| `networkClient`（`NetworkProviding`） | **可选能力**：需引入 `CYAppNetwork` 并注册，否则离线 App 不访问 | — |
| `imageLoader` | `CYDefaultImageLoader.shared`（URLSession） | singleton |
| `cacheManager` | `CYCacheManager.shared` | — |
| `logger` | `CYLogger.shared` | — |
| `analyticsService` | `CYAnalyticsService` | — |
| `requestDeduplicator` | `CYRequestDeduplicator` | singleton |
| `toastManager` | `CYToastManager.shared` | singleton |
| `loadingManager` | `CYLoadingManager.shared` | singleton |
| `alertManager` | `CYAlertManager.shared` | singleton |
| `themeManager` | `CYThemeManager.shared` | singleton |
| `localizationManager` | `CYLocalizationManager.shared` | singleton |
| `permissionManager` | `CYPermissionManager.shared` | — |

### 启动注册流程

```
App.init()
  │
  ├─► CYNetworkConfiguration.configure(...) ← 按需注册 networkClient（Alamofire）
  │     └─ Container.shared.networkClient.register { client }
  │
  ├─► CYAppImageConfig.configure()          ← 注册 imageLoader（Kingfisher）
  │     └─ Container.shared.imageLoader.register { CYKingfisherImageLoader() }
  │
  ├─► CYBusinessCodePolicy.configure { }    ← 配置业务码策略
  │
  └─► CYAppConstants.configure(...)         ← 覆盖默认常量
```

`CYNetworkConfiguration.configure` 内部用 `NSLock` + `precondition` 保护，只能调用一次。

### 替换服务

```swift
import FactoryKit

// 启动时替换
Container.shared.networkClient.register { EncryptedNetworkClient() }

// 账号能力由宿主显式创建或注册，不属于默认 DI 契约

// 也可使用 @Injected 属性包装器
@Injected(\.networkClient) private var networkClient
```

---

## 5. 状态管理

### 双层状态模型

```
┌─────────────────────────────────────────────┐
│  CYAppState（全局，App 生命周期）              │
│  @MainActor @Observable                      │
│  ├── theme: CYAppTheme（自动持久化）           │
│  └── language（backed by LocalizationManager）│
│  注入方式：.environment(appState)              │
│  消费方式：@Environment(CYAppState.self)       │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  CYBaseViewModel（页面级，局部）               │
│  @MainActor @Observable open class           │
│  ├── isLoading: Bool                         │
│  ├── error: CYAppError?                      │
│  ├── executeTask { } → 自动管理 loading/error │
│  └── retry() → 重放最后一次失败任务            │
│                                              │
│  CYPaginatedListViewModel<Item>（分页扩展）    │
│  ├── items: [Item]                           │
│  ├── hasMore / isLoadingMore / currentPage    │
│  └── load() / refresh() / loadMore()         │
└─────────────────────────────────────────────┘
```

### 分工原则

| 放 CYAppState | 放 ViewModel |
|---|---|
| 主题偏好 / 语言 | 搜索关键词 |
| App 生命周期通用偏好 | 页面列表数据 / loading / error |

### 错误模型

```
CYNetworkError（网络层，细粒度）
  .httpError / .businessError / .tokenExpired / .needReLogin / .decodingFailed / .cancelled
        │
        ▼  CYAppError.resolve(_:)
CYAppError（视图层，粗粒度）
  .network / .decoding / .business / .unknown
```

`CYBusinessCodePolicy`（线程安全，`OSAllocatedUnfairLock`）将后端 `code` 映射为 `CYBusinessCodeResult`（success / businessError / tokenExpired / needReLogin）和 `CYErrorDisplay`（toast / alert / silent）。

---

## 6. 路由系统

### CYAppRouter

`@MainActor @Observable`，持有 `.shared` 单例。

```
┌───────────────────────────────────────────────┐
│  CYAppRouter                                   │
│  paths: [CYTabID: NavigationPath]               │
│  ├── 每个 Tab 独立的 NavigationPath            │
│  ├── sheetItem: CYSheetItem?（类型擦除 Sheet）  │
│  └── selectedTab: CYTabID                      │
└───────────────────────────────────────────────┘
```

### 操作 API

| 方法 | 说明 |
|---|---|
| `navigate(to:on:)` | 前进，可选切换 Tab |
| `pop(on:)` | 后退一页 |
| `popToRoot(on:)` | 回到根页面 |
| `replace(with:on:)` | 替换当前栈 |
| `depth(for:)` | 获取栈深度 |
| `presentSheet(_:)` / `dismissSheet()` | Sheet 展示 |
| `binding(for:)` | 获取 `Binding<NavigationPath>` 供 `NavigationStack` 使用 |
| `bind(to:)` | 绑定 AppState（在 `.onAppear` 中调用） |

### 设计要点

- **路由类型由业务 App 定义**：Router 泛型为 `some Hashable`，消费方定义自己的 `Route` enum 并注册 `.navigationDestination(for: Route.self)`。
- **AppState 强引用**：`@ObservationIgnored` 强引用 `CYAppState`，避免弱引用静默失效。无循环引用，因为 AppState 由 Environment 持有。
- **深链接**：`CYDeepLinkHandler`（CYAppCore）按 scheme/host 解析 URL，分发到注册的闭包；App 在 `.onOpenURL` 中接入，通常在闭包内调用 `router.navigate(...)`。

---

## 7. 网络层架构

### 请求流程

```
                    ┌─────────────┐
                    │ CYEndpoint  │  协议：path / method / headers / body / queryItems / authentication
                    └──────┬──────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  构建 URLRequest         │
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  CYRequestInterceptor[]  │  请求拦截器链
              │  (加密 / 认证 / 日志)     │
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  Alamofire Session       │  发送请求（上传/下载支持进度回调）
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  CYResponseStrategy 解码  │  envelope / envelopeRaw / direct / empty / data
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  CYResponseInterceptor[] │  响应拦截器链（仅终态响应）
              └────────────┬────────────┘
                           │
                           ▼
                send(strategy:)  统一入口
                          │
            ┌─────────────┼─────────────────┐
            │             │                 │
            ▼             ▼                 ▼
       .envelope      .envelopeRaw      .direct
      自动解包 data   返回完整 CYAPIResponse  裸模型（第三方 API）
      业务码错误抛出   手动检查业务状态
```

### 响应策略 `CYResponseStrategy`

1.1.0 起所有请求统一路由到 `send(_:strategy:)`，按策略解码响应：

| 策略 | 解码目标 | 适用场景 |
|---|---|---|
| `.envelope` | `CYAPIResponse<T>` 的 `data` | 标准 `{code, data, message}` 包络，业务码错误自动抛出 |
| `.envelopeRaw` | 完整 `CYAPIResponse<T>` | 需要手动检查业务码/消息 |
| `.direct` | 裸 `T` | 无包络的第三方/开放 API |
| `.empty` | `CYEmptyResponse` | 204 / 空 body 接口 |
| `.data` | `Data` | 二进制下载内容 |

### 便捷 API

| API | 说明 |
|---|---|
| `requestVoid(_:)` | 无需返回值的接口（内部走 `.envelope` + `CYEmptyResponse`） |
| `requestData(_:)` | 直接返回 `Data`（内部走 `.data`） |
| `request<T>(body:strategy:)` | 泛型请求，支持 `Encodable` body 编码 |
| `upload(_:fileData:...)` / `upload(parts:)` | 单/多文件 multipart 上传，支持进度回调 |
| `download(_:to:)` | 下载到目标文件，支持进度回调 |

既有 `request` / `requestRaw` / `post` 保持协议要求不变，内部路由到 `send`，行为兼容。

### 错误模型（1.1.0 补充）

- 新增 `CYNetworkError.cancelled`：Task/URLSession 取消被识别为取消而非普通错误，`CYBaseViewModel` 自动忽略展示。
- 空响应 / 204 不再抛 `decodingFailed`（`CYEmptyResponse` 可用）。
- `buildURL` 自动规范化 baseURL 尾斜杠与 path 前导斜杠，避免双斜杠。
- 请求/响应日志自动脱敏（Authorization、Cookie、Token 等 Header 与 password/token 等 Body 字段）。

### 可选凭证恢复

```
请求失败（HTTP 401 或业务码 tokenExpired，且 endpoint.authentication == .required）
    │
    ▼
CYCredentialRecoveryCoordinator（Actor）
    │  ← 并发请求只恢复一次：第一个 401 触发恢复，
    │     其余 await 同一个 Task
    ▼
恢复成功 → 重放原请求（hasRefreshed 防循环）
恢复失败 → 保留并抛出原始认证错误
```

当前凭证恢复边界：

- `CYEndpoint.authentication` 默认 `.none`；仅 `.required` 端点允许触发凭证恢复。
- `requestRaw` 为完全 raw 语义：收到 HTTP 401 不自动刷新、不重放，直接抛 `httpError(401)`。
- 瞬态 401 不提前触发响应拦截器；终态认证失败由宿主决定如何处理。
- 恢复失败不递归、不重放，避免无限循环。

### 请求去重

`CYRequestDeduplicator`（Actor）按 `method + path + query + body` 生成 key，合并 500ms 内的相同并发请求，只发起一次网络调用。1.1.0 起去重 key 完整覆盖 `Encodable` body（不同 body 不会误合并）。

### 内置拦截器

| 拦截器 | 职责 |
|---|---|
| `CYLoggingInterceptor` | 请求 / 响应日志 |
| `CYCredentialInterceptor` | 按端点策略注入宿主提供的 Authorization Header |
| `CYCredentialRecovery` | 可选的凭证恢复与单次重放 |
| `CYAuthenticationFailureInterceptor` | 向宿主报告终态认证失败 |

---

## 8. 反馈与 UI 覆盖层

### 三层分离

```
状态管理器（CYAppCore/Managers）     ← @MainActor @Observable 单例 + 协议
    │                                   CYToastManager / CYLoadingManager / CYAlertManager
    │                                   队列管理、引用计数（Loading 的 showCount）
    │
视觉样式（CYFeedbackStyle）           ← 无依赖的纯样式 struct
    │                                   CYToastStyle / CYLoadingStyle / CYErrorStyle
    │                                   CYFeedbackConfiguration.configure(...) 全局配置
    │
视图接线（CYAppUI）                   ← SwiftUI 视图 + 修饰符
                                        CYToastView / CYLoadingOverlay / CYAlertManagerModifier
                                        .feedbackOverlay() / .toastView() / .loadingOverlay()
                                        .alertManager() / .snackBar()
```

`CYBaseView`（设计系统）统一了 Loading / Error / Content 三态，内部使用上述样式与反馈机制。

---

## 9. 持久化层

`CYAppPersistence` 完全解耦，不依赖模板内任何模块。

```
CYRepositoryProtocol（泛型 CRUD 协议）
  associatedtype Entity: PersistentModel
  func fetchAll() throws -> [Entity]
  func save(_ entity: Entity) throws
  func delete(_ entity: Entity) throws
  ...

CYPersistenceController
  ├── 使用宿主传入的模型类型创建 ModelContainer
  ├── 内存模式（测试用）/ 磁盘模式
  └── 可注入自定义 ModelConfiguration
```

具体 SwiftData 模型和 Repository 由宿主 App 持有；ExampleApp 提供 Bookmark/Tag 示例。

---

## 10. 并发模型

| 机制 | 使用位置 |
|---|---|
| `@MainActor` | AppState、Router、所有 Manager、BaseViewModel |
| `actor` | `CYRequestDeduplicator`、`CYCredentialRecoveryCoordinator`、`CYDefaultImageLoader`、`CacheStorage` |
| `Sendable` | 全量标注：模型、配置、拦截器、Endpoint |
| `OSAllocatedUnfairLock` | `CYBusinessCodePolicy` 等非 actor 共享状态 |
| `NSLock` | `CYNetworkConfiguration.configure` 的一次性保护 |
| `@unchecked Sendable` | 单例桥接隔离域 |

---

## 11. 扩展方式

### 特异化层级

| 层级 | 入口 | 适用场景 |
|------|------|---------|
| 零代码配置 | `.configure(...)` | 切换环境、样式、业务码、默认常量 |
| 协议实现 | 实现 `*Protocol` + DI 注册 | 替换网络、认证、分析、管理器 |
| 注入实例 | AppState init 参数 | 替换主题/语言管理策略 |
| 品牌色配置 | `CYAppColor.configure(primary:accent:)` | 零源码修改换主色 |
| 静态覆盖 | `CYAppFont.*` / 扩展 `CYAppColor` | 字体/衍生色定制 |

### 新增模块

1. 在 `Sources/` 下创建新目录
2. 在 `Package.swift` 中添加 `.target` 和 `.library` product
3. 声明对 `CYAppCore`（及所需模块）的依赖
4. 如需 DI 注册，创建 `*Config.configure()` 入口

### 新增组件

1. 在 `CYAppDesignSystem/Components/` 或 `CYAppUI/` 下创建文件
2. 遵循现有命名前缀 `CY`
3. 提供 SwiftUI Preview
4. 在 DocC 中补充 API 文档

---

## 12. 项目目录结构

```
CYSwiftTemplate/
├── Package.swift                  # SPM 配置（7 个 library + 1 个 executable）
├── .swiftlint.yml                 # 代码风格配置
├── .github/workflows/
│   └── ci.yml                     # CI（build + test + lint + iOS Simulator）
├── docs/                          # 文档
│   ├── TEMPLATE_RULES.md          # 模板开发规范
│   ├── GETTING_STARTED.md         # 完整接入指南
│   ├── NETWORK_GUIDE.md           # 网络框架使用指南
│   ├── ARCHITECTURE.md            # 架构设计（本文档）
│   ├── ROADMAP.md                 # 路线图
│   ├── REVIEW.md                  # 工程化评测（随版本更新）
│   └── archive/                   # 历史归档（网络重构记录、评测快照，不代表当前代码）
├── Sources/
│   ├── CYAppCore/                   # Layer 0: 纯逻辑（协议 + 工具）
│   │   ├── Network/               #   CYEndpoint, CYNetworkClientProtocol, APIResponse, BusinessCode
│   │   ├── Configuration/         #   AppEnvironment
│   │   ├── DI/                    #   DIContainerProtocol, NetworkProviding, FactoryContainer, AppContainer
│   │   ├── Services/              #   AuthService, AnalyticsService, UserSession
│   │   ├── Image/                 #   CYImageLoaderProtocol, ImageLoaderError
│   │   ├── Cache/                 #   CacheManager
│   │   ├── Permissions/           #   相机/相册/定位/通知权限
│   │   ├── Managers/              #   Toast/Loading/Alert 管理器 (协议 + DI)
│   │   ├── Mock/                  #   Mock 5 件套
│   │   └── ...
│   ├── CYAppNetwork/                # Layer 0: 网络实现（+Alamofire），可选
│   │   ├── AppConfiguration.swift #   启动配置（注册 networkClient）
│   │   └── Network/               #   按职责拆分的实现文件
│   │       ├── NetworkClient.swift          # 类核心 / 拦截器 / 凭证恢复 / send
│   │       ├── NetworkClient+Request.swift  # URL 构建 / 编解码 / 拦截器应用
│   │       ├── NetworkClient+Response.swift # 发送解码 / 业务码 / 错误映射
│   │       └── NetworkClient+Upload.swift   # 上传 / 下载
│   ├── CYAppImage/                  # Layer 0: 图片实现（+Kingfisher），可选
│   │   └── ImageLoader.swift      #   Kingfisher 桥接实现
│   ├── CYFeedbackStyle/            # Layer 0 UI: 样式定义
│   │   └── FeedbackConfiguration  #   CYToastStyle, CYLoadingStyle, CYFeedbackConfiguration
│   ├── CYAppDesignSystem/          # Layer 1: SwiftUI 设计系统
│   │   ├── Theme/                 #   CYAppColor(可配置), CYAppFont, CYAppDimens, Color扩展
│   │   └── Components/            #   BaseView, Buttons, Cards, Shimmer, PaginatedList
│   ├── CYAppUI/                    # Layer 2: SwiftUI 功能组件
│   │   ├── AppState.swift         #   全局状态（可注入 ThemeManager/LocalizationManager）
│   │   ├── Router/                #   AppRouter (多Tab NavigationStack + Sheet)
│   │   ├── Managers/              #   ToastView, LoadingOverlay, AlertManagerView
│   │   ├── Onboarding/            #   引导页
│   │   └── Extensions/            #   View/Animation/EdgeInsets 扩展
│   ├── CYAppPersistence/           # Layer 3: SwiftData 持久化（独立、可选）
│   │   ├── BookmarkItem.swift     #   @Model 示例
│   │   ├── BookmarkRepository.swift # Repository 实现
│   │   ├── PersistenceController.swift # ModelContainer 管理
│   │   └── RepositoryProtocol.swift  # CRUD 协议
│   ├── CYAppCoreTests/             # Core 层单元测试
│   ├── CYAppNetworkTests/          # 网络层测试（401、拦截器、上传、下载）
│   ├── CYAppPersistenceTests/      # SwiftData Repository 内存 CRUD 测试
│   ├── CYAppUITests/               # UI 层测试 (Router + AppState + Feedback)
│   ├── CYAppDesignSystemTests/     # 设计系统测试
│   └── CYFeedbackStyleTests/       # 反馈样式测试
└── ExampleApp/                     # 可运行范例（App / Features / Models / Services）
    └── Sources/
        ├── App/                    #   @main、AppConfig、AppBootstrap、Tab、Route、Persistence
        ├── Models/                 #   Article（网络域）、BookmarkItem（持久化域）
        ├── Services/               #   ArticleService
        └── Features/               #   Home / Bookmark / Settings
```
