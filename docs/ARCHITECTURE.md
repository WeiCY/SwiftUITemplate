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

| 原则 | 实践 |
|---|---|
| **协议驱动** | 所有子系统以 `*Protocol` 暴露抽象：网络、认证、分析、缓存、图片加载、反馈管理器、主题、多语言、权限、持久化 Repository |
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
                    ExampleApp (Demo)
```

**关键规则**：`CYAppCore` 只定义协议，Alamofire 和 Kingfisher 实现被隔离在各自模块中。一个项目可以只依赖 `CYAppCore`，仍能获得可工作的（基础版）网络与图片加载默认实现。

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
| `ExampleApp` | CYAppCore, CYAppNetwork, CYAppImage, CYFeedbackStyle, CYAppDesignSystem, CYAppUI |

---

## 3. 各模块职责

### CYAppCore（Layer 0 — 核心骨架）

整个模板的基础，遵循 **协议驱动 + DI 注入** 的设计原则。

| 子目录 | 职责 | 关键类型 |
|---|---|---|
| `Network/` | 网络协议层 | `CYEndpoint`, `CYNetworkClientProtocol`, `CYAPIResponse<T>`, `CYBusinessCodePolicy`, `CYRequestInterceptor`, `CYResponseInterceptor`, `CYRequestDeduplicator`, `CYTokenRefreshCoordinator` |
| `Services/` | 认证 / 分析 / 用户会话 | `AuthServiceProtocol`, `CYAuthService`, `CYAnalyticsServiceProtocol`, `CYUserSession`, `TokenPair`, `User` |
| `DI/` | 依赖注入 | `DIContainerProtocol`, `CYFactoryContainer`, `CYAppContainer` |
| `Configuration/` | 环境配置 | `CYAppEnvironment` |
| `Constants/` | 全局常量 | `CYAppConstants`, `CYAppConfigurationValues`, `CYSFSymbol` |
| `Cache/` | Actor 隔离缓存 | `CYCacheManager`, `CYCacheSerializer` |
| `Managers/` | 反馈管理器（协议 + 单例） | `CYToastManager`, `CYLoadingManager`, `CYAlertManager` |
| `Permissions/` | 权限管理 | `CYPermissionManager`, `CYPermissionType`, `CYPermissionRequester` |
| `Image/` | 图片加载协议 | `CYImageLoaderProtocol`, `CYDefaultImageLoader` |
| `Logger/` | 日志 | `CYLogger`, `CYLogLevel` |
| `Helpers/` | 工具类 | `CYKeychainHelper`, `CYBiometricAuth`, `CYFormValidator`, `CYDebouncer`, `CYThrottler`, `CYDeepLinkHandler`, `CYNetworkMonitor`, `CYThemeManager`, `CYLocalizationManager` |
| `Mock/` | 测试 Mock | `MockNetworkClient`, `MockAuthService`, `MockAnalyticsService`, `MockToastManager`, `MockLoadingManager` |
| `Base/` | ViewModel 基类 | `CYBaseViewModel`, `CYPaginatedListViewModel<Item>`, `CYAppError`, `CYAppTab`, `CYAppTheme` |
| `Extensions/` | Foundation 扩展 | Collection, String, Date, Data, Optional, Numeric, Dictionary, Bundle 等 16 个文件 |

### CYAppNetwork（Layer 0 — 网络实现）

Alamofire 桥接层。

| 文件 | 职责 |
|---|---|
| `AppConfiguration.swift` | `CYAppConfiguration` — 启动配置器，构建 `CYNetworkClient` 并注册到 Factory |
| `Network/NetworkClient.swift` | `CYNetworkClient` — 实现 `CYNetworkClientProtocol`，包含拦截器链、401/Token 刷新重放、请求去重 |

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
| `Theme/` | `CYAppColor`, `CYAppFont`, `CYAppDimens`, Color+Hex 扩展 |
| `Components/` | `CYBaseView`, `PrimaryButton`/`SecondaryButton`/`CYScaledButtonStyle`, `CardView`, `EmptyStateView`, `CYTextField`/`CYSearchBar`/`CYVerificationCodeInput`, `CYListRow`/`CYSectionHeader`, `CYPaginatedListView`, `CYBadge`/`CYTag`, `ShimmerModifier`/`SkeletonRow`, `CYBottomSheetModifier`/`CYSnackBar` |

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
| `BookmarkItem.swift` | `CYBookmarkItem` (@Model), `CYTag` (@Model) |
| `PersistenceController.swift` | `CYPersistenceController` — ModelContainer 管理 |
| `RepositoryProtocol.swift` | `CYRepositoryProtocol` — 泛型 CRUD 协议 |
| `BookmarkRepository.swift` | `CYBookmarkRepository`, `CYTagRepository` |

> **注意**：`CYTag` 在两个模块中存在 — `CYAppDesignSystem` 中是 SwiftUI **View**，`CYAppPersistence` 中是 SwiftData **@Model**。由于在不同模块，不会冲突。

---

## 4. 依赖注入（DI）

### 三层架构

```
DIContainerProtocol          ← 业务代码依赖的抽象（14 个服务 getter）
       ▲
       │ implements
       │
CYFactoryContainer           ← Factory 实现（注册 Factory<T>）
       ▲
       │ delegates
       │
CYAppContainer               ← 业务代码使用的门面（.shared.authService）
```

### 服务注册

| 服务 | 默认实现 | 生命周期 |
|---|---|---|
| `networkClient` | **必须注入**（`preconditionFailure`） | — |
| `imageLoader` | `CYDefaultImageLoader.shared`（URLSession） | singleton |
| `userSession` | `CYUserSession()` | singleton |
| `cacheManager` | `CYCacheManager.shared` | — |
| `logger` | `CYLogger.shared` | — |
| `authService` | `CYAuthService` | — |
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
  ├─► CYAppConfiguration.configure(...)     ← 注册 networkClient（Alamofire）
  │     └─ Container.shared.networkClient.register { client }
  │
  ├─► CYAppImageConfig.configure()          ← 注册 imageLoader（Kingfisher）
  │     └─ Container.shared.imageLoader.register { CYKingfisherImageLoader() }
  │
  ├─► CYBusinessCodePolicy.configure { }    ← 配置业务码策略
  │
  └─► CYAppConstants.configure(...)         ← 覆盖默认常量
```

`CYAppConfiguration.configure` 内部用 `NSLock` + `precondition` 保护，只能调用一次。

### 替换服务

```swift
import FactoryKit

// 启动时替换
Container.shared.networkClient.register { EncryptedNetworkClient() }

// 测试中 Mock
Container.shared.authService.register { MockAuthService(userSession: CYUserSession()) }

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
│  ├── user / isLoggedIn                       │
│  ├── selectedTab: CYAppTab                   │
│  ├── theme: CYAppTheme（自动持久化）           │
│  ├── language（backed by LocalizationManager）│
│  └── hasCompletedOnboarding（自动持久化）      │
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
| 当前用户 / 登录状态 | 页面列表数据 |
| 选中 Tab / 路由状态 | 页面 loading / error |
| 主题偏好 / 语言 | 搜索关键词 |
| 引导页完成状态 | 表单输入内容 |

### 错误模型

```
CYNetworkError（网络层，细粒度）
  .httpError / .businessError / .tokenExpired / .needReLogin / .decodingFailed
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
│  paths: [CYAppTab: NavigationPath]             │
│  ├── 每个 Tab 独立的 NavigationPath            │
│  ├── sheetItem: CYSheetItem?（类型擦除 Sheet）  │
│  └── 强引用 AppState（@ObservationIgnored）     │
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
                    │ CYEndpoint  │  协议：path / method / headers / body / queryItems
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
              │  Alamofire Session       │  发送请求
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  解码 CYAPIResponse<T>   │  {code, data, message}
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │  CYResponseInterceptor[] │  响应拦截器链
              └────────────┬────────────┘
                           │
                    ┌──────┴──────┐
                    │             │
                    ▼             ▼
            .request()      .requestRaw()
          自动解包 data     返回完整 response
          业务码错误抛出     手动处理 businessResult
```

### Token 自动刷新

```
请求失败（HTTP 401 或业务码 tokenExpired）
    │
    ▼
CYTokenRefreshCoordinator（Actor）
    │  ← 并发请求只刷新一次：第一个 401 触发刷新，
    │     其余 await 同一个 Task
    ▼
刷新成功 → 重放原请求（hasRefreshed 防循环）
刷新失败 → 抛出 CYNetworkError.needReLogin
```

### 请求去重

`CYRequestDeduplicator`（Actor）按 `method + path + query + body` 生成 key，合并 500ms 内的相同并发请求，只发起一次网络调用。

### 内置拦截器

| 拦截器 | 职责 |
|---|---|
| `CYLoggingInterceptor` | 请求 / 响应日志 |
| `CYAuthInterceptor` | Bearer Token 注入 |
| `CYTokenRefreshInterceptor` | Token 过期拦截 |
| `CYAutoLogoutInterceptor` | 需重新登录时自动登出 |

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

CYBookmarkRepository: CYRepositoryProtocol   ← Entity = CYBookmarkItem
CYTagRepository: CYRepositoryProtocol        ← Entity = CYTag

CYPersistenceController
  ├── ModelContainer 管理
  ├── 内存模式（测试用）/ 磁盘模式
  └── 可注入自定义 ModelConfiguration
```

此模块展示了如何用 SwiftData + 泛型 Repository 模式实现持久化，与网络层「协议 vs 实现」的分离理念一致。

---

## 10. 并发模型

| 机制 | 使用位置 |
|---|---|
| `@MainActor` | AppState、Router、所有 Manager、BaseViewModel |
| `actor` | `CYRequestDeduplicator`、`CYTokenRefreshCoordinator`、`CYDefaultImageLoader`、`CacheStorage` |
| `Sendable` | 全量标注：模型、配置、拦截器、Endpoint |
| `OSAllocatedUnfairLock` | `CYBusinessCodePolicy` 等非 actor 共享状态 |
| `NSLock` | `CYAppConfiguration.configure` 的一次性保护 |
| `@unchecked Sendable` | 单例桥接隔离域 |

---

## 11. 扩展方式

### 特异化层级

| 层级 | 入口 | 适用场景 |
|------|------|---------|
| 零代码配置 | `.configure(...)` | 切换环境、样式、业务码、默认常量 |
| 协议实现 | 实现 `*Protocol` + DI 注册 | 替换网络、认证、分析、管理器 |
| 注入实例 | AppState init 参数 | 替换主题/语言管理策略 |
| 静态覆盖 | `AppColors.*` / `AppFonts.*` | 品牌色/字体定制 |

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
│   ├── GETTING_STARTED.md         # 完整接入指南
│   ├── ARCHITECTURE.md            # 架构设计（本文档）
│   ├── ROADMAP.md                 # 路线图
│   └── REVIEW.md                  # 评测快照
├── Sources/
│   ├── CYAppCore/                   # Layer 0: 纯逻辑（协议 + 工具）
│   │   ├── Network/               #   CYEndpoint, CYNetworkClientProtocol, APIResponse, BusinessCode
│   │   ├── Configuration/         #   AppEnvironment
│   │   ├── DI/                    #   DIContainerProtocol, FactoryContainer, AppContainer
│   │   ├── Services/              #   AuthService, AnalyticsService, UserSession
│   │   ├── Image/                 #   CYImageLoaderProtocol, ImageLoaderError
│   │   ├── Cache/                 #   CacheManager
│   │   ├── Permissions/           #   相机/相册/定位/通知权限
│   │   ├── Managers/              #   Toast/Loading/Alert 管理器 (协议 + DI)
│   │   ├── Mock/                  #   Mock 5 件套
│   │   └── ...
│   ├── CYAppNetwork/                # Layer 0: 网络实现（+Alamofire），可选
│   │   ├── NetworkClient.swift    #   Alamofire 桥接实现
│   │   └── AppConfiguration.swift #   启动配置（注册 networkClient）
│   ├── CYAppImage/                  # Layer 0: 图片实现（+Kingfisher），可选
│   │   └── ImageLoader.swift      #   Kingfisher 桥接实现
│   ├── CYFeedbackStyle/            # Layer 0 UI: 样式定义
│   │   └── FeedbackConfiguration  #   CYToastStyle, CYLoadingStyle, CYFeedbackConfiguration
│   ├── CYAppDesignSystem/          # Layer 1: SwiftUI 设计系统
│   │   ├── Theme/                 #   AppColors, AppFonts, AppDimens, Color扩展
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
└── ExampleApp/                     # 可运行 Demo
    └── Sources/
        └── ExampleApp.swift        # 3 Tab 示例
```
