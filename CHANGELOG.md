# 变更记录

> 本文档仅记录已发布的版本变更。未来计划请查看 [docs/ROADMAP.md](docs/ROADMAP.md)。
>
> 版本号遵循 [语义化版本（Semantic Versioning）](https://semver.org/lang/zh-CN/) 规范：`MAJOR.MINOR.PATCH`

---

## 版本历史

### [1.0.0] - 2026-08-10

**首个正式发布版本** - 核心功能完整，98 个测试全部通过。

#### 新增功能

**架构与基础设施**
- 7 个 SPM Library 模块化架构（CYAppCore / CYAppNetwork / CYAppImage / CYFeedbackStyle / CYAppDesignSystem / CYAppUI / CYAppPersistence）
- Swift 6 严格并发安全（`swiftLanguageModes: [.v6]`）
- iOS 18 + macOS 15 部署目标
- Factory DI 依赖注入框架集成
- GitHub Actions CI 流水线（build + test + lint + iOS Simulator）

**网络层（CYAppCore + CYAppNetwork）**
- `CYEndpoint` 协议：类型安全的 API 定义
- `CYNetworkClientProtocol`：协议驱动的网络客户端
- `CYAPIResponse<T>`：统一响应包装，自动解包
- `CYBusinessCodePolicy`：可配置的业务状态码策略
- Token 自动刷新 + 401 重放（Actor 隔离，并发安全）
- 请求去重（Actor 隔离，防止重复请求）
- 请求/响应拦截器链
- 文件上传/下载支持

**状态管理（CYAppUI）**
- `CYAppState`：全局状态容器（@Observable）
- `CYBaseViewModel`：页面级状态基类（loading/error/retry）
- `CYPaginatedListViewModel<Item>`：泛型分页列表
- `CYAppRouter`：多 Tab NavigationStack 路由

**UI 组件库（CYAppDesignSystem + CYAppUI）**
- 主题系统：`CYAppColor` / `CYAppFont` / `CYAppDimens`
- 反馈组件：Toast / Loading / Alert / SnackBar / BottomSheet
- 基础组件：Button / TextField / SearchBar / VerificationCode
- 列表组件：ListRow / SectionHeader / PaginatedList
- 展示组件：Badge / Tag / Card / EmptyState / Shimmer
- 功能组件：Onboarding / RemoteImage / MediaPicker / ShareSheet

**工具与辅助（CYAppCore）**
- `CYKeychainHelper`：Keychain 安全存储
- `CYCacheManager`：Actor 隔离缓存（内存 + 磁盘 + TTL）
- `CYBiometricAuth`：Face ID / Touch ID / Optic ID
- `CYFormValidator`：声明式表单验证
- `CYPermissionManager`：统一权限管理（相机/相册/定位/通知）
- `CYNetworkMonitor`：NWPathMonitor 网络状态监听
- `CYDeepLinkHandler`：深链接处理
- `CYHapticFeedback`：触觉反馈
- `CYDebouncer` / `CYThrottler`：防抖/节流
- `CYLogger`：os.Logger 封装
- 全量本地化（en + zh-Hans，60+ key）

**持久化（CYAppPersistence）**
- SwiftData `@Model` + `ModelContainer`
- Repository 模式（CRUD + 分页 + 搜索）
- 内存/磁盘双模式

**测试**
- 98 个单元测试，覆盖 Core / Network / UI / DesignSystem / FeedbackStyle
- Mock 实现：NetworkClient / AuthService / AnalyticsService / ToastManager / LoadingManager

#### 修复问题

- `CYAppColor.primary` 深色模式白底白字
- `SkeletonRow.widthRatio` 无效
- `AppStorageHelper.clearAll()` 跨进程清理
- `BiometricAuth.localizedFallbackTitle` 语义错误
- `ExampleApp` 未注册 `imageLoader` 崩溃
- `CYNetworkClient` 401 无限重试循环
- `LoadingManager` 并发请求提前关闭
- `AlertManager` 连续调用覆盖
- `CYAppState` 可观察性（@ObservationIgnored 移除）
- 上传 API 协议与实现不一致
- 核心层硬编码中文（全量本地化）
- 请求去重键复杂 body 冲突
- `CYThrottler` trailing 定时器叠加
- `TypewriterModifier` 视图消失后继续执行
- `DateFormatter` 重复创建（缓存优化）
- `RemoteImageView` 冗余 `retryCount`

#### 文档

- README.md：项目概览与快速开始
- docs/GETTING_STARTED.md：完整接入指南
- docs/ARCHITECTURE.md：架构设计
- docs/ROADMAP.md：路线图
- docs/REVIEW.md：评测快照
- DocC：CYAppCore API 文档
- ExampleApp：3 Tab 可运行 Demo

---

## 迁移指南

### 初始版本

1.0.0 为首个正式发布版本，无需迁移。
