# 变更记录

> 已发布版本的变更记录在下方；尚未发布的进行中变更统一放在 [Unreleased] 小节。未来计划请查看 [docs/ROADMAP.md](docs/ROADMAP.md)。
>
> 版本号遵循 [语义化版本（Semantic Versioning）](https://semver.org/lang/zh-CN/) 规范：`MAJOR.MINOR.PATCH`

---

## 版本历史

### [Unreleased]

#### ExampleApp（一致性收尾）

- `ArticleService` 移除默认参数，改由组合根显式注入，不再引用 Legacy Facade `CYAppContainer.shared`
- 新增 `AppDependencies` 组合根；`HomeView` / `BookmarkView` 改为接收注入的 ViewModel
- 长期文档（`README` 等）不再写死测试数量，统一引用 CHANGELOG

#### 文档

- 收敛文档结构：`NETWORK_REFACTOR_PLAN` 与 `REVIEW` 归档至 `docs/archive/`（标注为历史快照，不代表当前代码）
- `APP_FACTORY_GUIDE` 内容合并进 `TEMPLATE_RULES`（模块选择 / 宿主目录 / 新 App 工作流 / 边界 / 验收清单）与 `README`，移除独立文件
- `ROADMAP` 更新 1.2.0 状态，删除与 `TEMPLATE_RULES` 重复的开发流程章节
- `GETTING_STARTED` 网络章节收敛并链接 `NETWORK_GUIDE`，修正过期的 Mock 示例

### [1.2.0] - 2026-10-09

**App Factory 基线** - DI 能力拆分 + ExampleApp 接入范例重构，161 个测试全部通过。

> 本次含一处源码不兼容变更（`DIContainerProtocol.networkClient` 移出）。
> 因暂无外部消费者，按 MINOR 发布；后续累积为 2.0.0 时再统一说明。

#### 架构 / DI（CYAppCore）

##### 变更（源码不兼容）
- `networkClient` 从 `DIContainerProtocol` 拆出，新增可选能力协议 `NetworkProviding`
- `CYFactoryContainer` / `CYAppContainer` 现遵循 `DIContainerProtocol & NetworkProviding`
- 网络 Feature 应声明 `any DIContainerProtocol & NetworkProviding`；离线 Feature 只依赖 `DIContainerProtocol`
- `CYAppContainer` 明确标注为 Legacy / Compatibility Facade，新代码优先使用初始化注入或 `@Injected`

#### ExampleApp（重构为真实接入范例）

- 目录重构为 `App / Models / Services / Features`，可直接作为新项目复制模板
- 新增网络域模型 `Article`、持久化域模型 `BookmarkItem` / `BookmarkTag`
- 新增 `ArticleService`（收敛网络访问）与 `BookmarkRepository`（`CYRepositoryProtocol`）
- `HomeViewModel` 演示 `executeTask` 的 loading / error / retry，`HomeView` 用 `CYBaseView` 渲染
- 接入 `CYAppRouter` 路由、SwiftData `modelContainer`、`SettingsView` 主题 / 语言切换
- `AppBootstrap` 在 DI 注册 `MockNetworkClient`，无后端也可运行完整流程
- ExampleApp target 新增 `FactoryKit` 依赖（组合根注册 Mock）

#### 网络层（CYAppCore + CYAppNetwork）

##### 修复与一致性
- 删除未被调用的 `fetchRaw` 重载（死代码）
- `NetworkFailure` 标注 `Sendable`，消除跨并发边界的隐性隐患
- 文档修正：`requestVoid` 实际走 `.envelope` + `CYEmptyResponse`（并非 `.empty`）；补充 `requestData` 的 raw 语义（不触发凭证恢复、不参与去重）
- `CYLoggingInterceptor` 文档示例与实际输出对齐（去除不存在的耗时）

##### 结构重构（行为不变）
- `CYNetworkClient`（原 734 行）拆分为 `NetworkClient` / `+Request` / `+Response` / `+Upload`
- `NSLock` + `@unchecked Sendable` → `Mutex`（iOS 18 `Synchronization`）；`CYNetworkClient` 与 `MockNetworkClient` 现为真正的 `Sendable`
- `requestWithDeduplication` 提升到 `CYNetworkClientProtocol` 扩展，生产客户端与 Mock 通用
- 删除未使用的 `CYHTTPMethod.alamofireMethod` 桥接

##### 新增
- `MockNetworkClient` 请求记录：`recordedRequests` / `CYMockRequestRecord` / `clearRecordedRequests()`，可断言方法、路径、Body 与上传分片

#### 组件库（CYAppDesignSystem）

##### 修复
- `CYFlowLayout`（由私有 `FlowLayout` 抽取）：修复宽度未指定时返回无限宽的布局缺陷
- `ShimmerModifier` 尊重 `accessibilityReduceMotion`

##### 新增 / 扩展
- `CYAppColor.configure(primary:accent:)` 与 `reset()`：品牌色可配置，零源码修改换主色
- 公共 `CYFlowLayout`（标签 / 筛选换行布局）
- `CYTextField` 增强：`submitLabel` / `autocorrectionDisabled` / `showsClearButton` / `onSubmit`；iOS 专属重载支持 `keyboardType` / `textContentType` / `textInputAutocapitalization`
- `CardView` 支持自定义 `padding` / `cornerRadius` / `backgroundColor` / `appliesShadow`
- `CYListRow` 无 `action` 时不再渲染为 `Button`
- 新增 `clear` 本地化键（en / zh-Hans）
- 设计系统预览新增暗黑模式、大字号变体

##### 现代化
- `.foregroundColor` → `.foregroundStyle`（30 处）
- `.cornerRadius` → `.clipShape(.rect(cornerRadius:))`（10 处，外观等价）

##### 破坏性变更与迁移

| 移除项 | 替代写法 |
|---|---|
| `EmptyStateView`（旧名弃用包装） | `CYEmptyStateView(systemImage:title:message:...)` |
| `CYAppDimens.radiusFull` | `.clipShape(.capsule)` |

#### UI 层（CYAppUI）

##### 修复
- `CYRemoteImageView` 删除从未被读取的 `isLoading` 死状态
- 引导页 `CYOnboardingView`：`pages` 为空时不再错乱（自动视为已完成），并修正「下一页」按钮越界逻辑
- `CYMediaPicker`（`.system` 样式）：选择后清空 `photoItems`，重复选择同一张可再次触发回调
- `CYPhotoAssetLoader`：Photos 回调补充取消/错误分支，避免 continuation 挂起
- `CYView+Gradient`：删除与系统同名、且语义错误的私有 `strokeBorder`（内描边改为系统实现）

##### 无障碍
- 网格拍照按钮、预览关闭按钮补充 `accessibilityLabel`
- `TypewriterModifier` 尊重 `accessibilityReduceMotion`

##### 跨平台 / 一致性
- `CYRemoteImageView` 支持 iOS / macOS（`UIImage` / `NSImage` 双平台）
- `CYOnboardingPage` 标注 `Sendable`，移除 `nonisolated(unsafe)`
- `CYAppRouter.shared` 补充单例语义说明（避免与 `init(tabs:)` 实例混用）

##### 测试
- 新增 Router 边界测试：`replace`、空栈 `pop`、跨 Tab `popToRoot`、`selectTab` 补建路径、Sheet 展示/关闭

#### 核心工具层（CYAppCore）

##### 修复
- `UIImage.withTintColor`：`cgImage` 缺失时强制解包会崩溃，改为安全回退原图
- `String.urlEncoded`：在 `.urlQueryAllowed` 基础上额外转义 `& = + ? /`，避免 query 值破坏参数结构（`Dictionary.queryString` 同受益）
- `Dictionary.prettyJSON`：此前输出紧凑 JSON，改为真正缩进输出（与 `Data.prettyJSON` 一致）
- `Task.retry`：退避改用亚秒精度，修复延迟 < 1s 时退避被截断为 0 的问题
- `CYAppTheme.displayName` / `ImageLoaderError.errorDescription`：由硬编码中文改为 `.cyLocalized`（新增 `theme_system` / `theme_light` / `theme_dark` 本地化键）

##### 结构与一致性
- `DeepLinkHandler.swift`：修正结构错位（`HandlerEntry` 由文件作用域移入类内，文档注释归位）
- 删除 `Sequence.count(where:)`（Swift 6 标准库已提供，属冗余）
- `CYBundleDecodingError` 补充 `LocalizedError` 与 `Sendable`，并提供本地化 `errorDescription`（新增 `bundle_file_*` 键）

##### 并发现代化
- 一批无状态类由 `@unchecked Sendable` 收敛为编译器校验的 `Sendable`：`CYKeychainHelper`、`CYLogger`、`CYThemeManager`、`CYFactoryContainer`、`CYAppContainer`
- `CYAppConstants` 的配置存储改用 `OSAllocatedUnfairLock`（移除 `NSLock` + `nonisolated(unsafe)`）
- `Date` 的 `DateFormatter` 缓存改用 `OSAllocatedUnfairLock`，并将格式化放入锁内执行，消除共享 `DateFormatter` 并发调用的线程安全不确定性
- 移除 `CYCacheManager` 上无观察状态的 `@Observable`

#### 文档
- 同步 `ARCHITECTURE.md`（网络文件拆分、组件清单、品牌色配置）
- 同步 `NETWORK_GUIDE.md`（`requestData` raw 语义、`.empty` 说明、Mock 请求记录）
- 同步 `GETTING_STARTED.md`（品牌色配置、业务码策略 API 名修正）

---

### [1.1.0] - 2026-08-23

**网络层能力升级与缺陷修复** - 156 个测试全部通过。

#### 修复（Batch 1–6）

- 取消请求识别：`CYNetworkError.cancelled`，Task/URLSession 取消不再被当作普通错误展示
- 空响应 / 204：`CYEmptyResponse` 真正可用（缺 data 键、data 为 null、204 No Content 均成功）
- `buildURL` 斜杠规范化：baseURL 尾斜杠 + path 前导斜杠不再产生双斜杠
- multipart 数值参数修复：`endpoint.body` 的 Int/Bool/Double 不再被静默丢弃
- 日志脱敏：`Authorization`/`Cookie`/`Token` 等 Header 与 `password`/`token` 等 Body 字段不再打印原始值
- Token 刷新边界：
  - `CYEndpoint.allowsTokenRefresh`（认证类端点可禁用自动刷新，防止递归）
  - `requestRaw` 改为完全 raw 语义（401 不再自动刷新 + 重放）
  - 瞬态 401 不再提前触发响应拦截器（自动登出不提前触发）
  - 刷新失败不递归、不重放

#### 新增能力（Batch 7–15）

- `CYResponseStrategy` + `send` API：envelope / envelopeRaw / direct / empty / data 五种响应策略
- `requestVoid` / `requestData` / 泛型 `request(body:)` 便捷 API
- `upload(parts:)` 多文件上传 + 上传/下载进度回调
- 下载取消传播：Task 取消会取消底层请求，错误映射为 `.cancelled`
- 请求去重支持 Encodable body（不同 body 不误合并）
- Mock 全 API 可用（`requestRaw` 缺陷修复）
- 错误日志带上下文（方法 + 路径 + HTTP 状态码）
- 现有 `request` / `requestRaw` / `post` 内部统一路由到 `send`（行为不变）

#### 组件与工程改进

- 提取 `CYLoadingIndicator` 公共组件：`CYBaseView` 与 `CYLoadingOverlay` 复用同一指示器，视觉 / 脉冲动画 / 无障碍行为一致，脉冲初始值与无障碍标签已统一（本地化）
- 文档同步：ARCHITECTURE / ROADMAP / REVIEW 与 1.1.0 现状对齐，补充 NETWORK_GUIDE 与 NETWORK_REFACTOR_PLAN

#### 行为变更提醒

- `requestRaw` 收到 HTTP 401 不再触发自动刷新，直接抛 `httpError(401)`
- 响应拦截器只收到终态响应（瞬态 401 不再触发）

### [1.0.1] - 2026-08-10

**1.0.0 发布后的即时修复** - 98 个测试全部通过。

- 修复 `upload` 方法参数过多导致的 `function_parameter_count` SwiftLint 违规
- 网络协议与 Mock 实现对齐（`NetworkClientProtocol` / `CYNetworkClient` / `MockNetworkClient`）

> 该 PATCH 已随 1.0.1 tag 发布；网络层能力升级在 1.1.0 中完成。

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

### 1.2.0

`DIContainerProtocol` 不再包含 `networkClient`，改为独立的 `NetworkProviding`。

- 网络 Feature：把依赖类型改为 `any DIContainerProtocol & NetworkProviding`。
- 离线 Feature：保持 `any DIContainerProtocol` 即可，无需处理网络。
- `CYAppContainer.shared.networkClient` 仍可用（`CYAppContainer` 同时遵循两个协议），但该类型已标记为 Legacy Facade，新代码建议初始化注入或 `@Injected`。

### 初始版本

1.0.0 为首个正式发布版本，无需迁移。
