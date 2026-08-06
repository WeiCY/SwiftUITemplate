# CYSwiftTemplate 评审报告与下阶段开发方案

> 评审日期：2026-08-06  
> 评审范围：Package.swift、CYAppCore、CYAppNetwork、CYAppImage、CYAppDesignSystem（含新增组件）、CYAppUI、CYAppPersistence、CYAppCoreTests、ExampleApp、.swiftlint.yml、CI  
> 当前状态：`swift build` 通过，`swift test` 98 个测试全部通过

---

## 1. 整体评分

| 维度 | 评分 | 说明 |
|---|---|---|
| 架构分层 | 9.0 | 模块划分清晰，依赖由底层向顶层收敛，DI + 协议抽象到位，可选模块可插拔。 |
| 可维护性 | 8.0 | 命名规范、注释详尽、Swift 6 + async/await + Actor，结构整齐。少量硬编码文案、重复实现、UIKit 通用代码混杂待优化。 |
| 可测试性 | 8.0 | Mock 与协议抽象完整，测试数量较多。但网络/图片/权限/持久化等核心链路测试不足，部分测试依赖全局单例。 |
| 可配置性 | 7.0 | 环境、网络、业务码、反馈样式可配置。核心默认值（缓存目录、Keychain、验证文案、上传字段名等）仍大量写死。 |
| 组件完整性 | 8.5 | 已覆盖 Button、Input、Search、Verification、List、Badge、Tag、Overlay、SnackBar、Toast、Loading、Alert、Skeleton、Paginated、Onboarding、RemoteImage、MediaPicker、ShareSheet 等。 |
| 文档/示例 | 9.0 | README 详尽，包含用法、特异化指南、对比表和项目结构。示例 App 能跑通 3 Tab 基础流程。 |
| CI/工程化 | 7.5 | SwiftLint + build + test 流水线完整，但只跑 macOS 原生编译，未验证 iOS 模拟器/ExampleApp。 |
| 代码质量 | 8.0 | 线程安全意识强，但存在若干逻辑缺陷（401 重试循环、AppState 可观察性、去重键等）需要立即修复。 |

**总分：8.0 / 10**

---

## 2. 本次已完成的优化

### 高风险修复
1. `CYAppColor.primary` 从 `Color.primary` 改为固定品牌色，修复深色模式主按钮白底白字。
2. 修复 `SkeletonRow.widthRatio` 无效问题。
3. 修复 `AppStorageHelper.clearAll()` 无法清理跨进程/历史数据。
4. 修复 `BiometricAuth` 的 `localizedFallbackTitle` 语义错误。
5. 修复 `ExampleApp` 未注册 `imageLoader` 导致的崩溃。
6. 修复 `CYNetworkClient` 401/Token 刷新失败时的无限重试循环：最多只刷新一次，刷新失败或重放后仍 401 直接抛出错误。

### DI 按需注册优化
7. 新增 `CYDefaultImageLoader`（基于 `URLSession`），默认注册到 DI；导入 `CYAppImage` 后可被 Kingfisher 实现覆盖。

### 中低风险修复
8. `LoadingManager` 增加引用计数，避免并发请求提前关闭。
9. `AlertManager` 增加弹窗队列，避免连续调用覆盖。
10. `BaseView` 错误视图支持 `CYErrorStyle` 配置和自定义 `errorView` 插槽。
11. `OnboardingView` 支持外部注入 `pages`。
12. `CYPersistenceController` 支持通过 `containerBuilder` 闭包自定义 `ModelContainer`。
13. `EmptyStateView` 增加图标颜色/尺寸/操作按钮配置。
14. `RemoteImageView` 增加 `maxRetries`、`retryDelay`、`errorRetryTitle` 配置。
15. `CYPermissionType` 从 `enum` 改为 `struct`，支持业务扩展。
16. `NotificationPermission` 支持自定义 `UNAuthorizationOptions`。
17. 本地化 `AlertManager` 的确认/成功/错误/警告标题。

### 组件库补充
18. 新增 `InputComponents.swift`：`CYTextField`、`CYSearchBar`、`CYVerificationCodeInput`。
19. 新增 `ListComponents.swift`：`CYListRow`、`CYSectionHeader`。
20. 新增 `OverlayComponents.swift`：`.cyBottomSheet`、`.snackBar`、`CYSnackBarManager`。
21. 新增 `BadgeAndTag.swift`：`CYBadge`、`CYTag`、`CYTagGroup`。

### 测试
22. 新增 `CYAppNetworkTests` 测试目标，覆盖 `CYNetworkClient` 401 刷新/重试/不重试/不循环等 5 个用例。
23. 新增 `Toast` 队列上限测试、`AlertManager` 队列测试。当前共 **98 个测试，0 失败**。

---

## 3. 仍存在的具体问题

### 高严重度（建议立即修复）

#### 1. 401 / Token 刷新失败时可能无限重试 ✅ 已修复
- **位置**：`Sources/CYAppNetwork/Network/NetworkClient.swift` ~92–118
- **修复**：将 `performRequest` 改为最多只触发一次刷新；刷新失败（`coordinator.refreshIfNeeded()` 返回 `nil`）直接抛出原错误；重放后仍 401 不再二次刷新。
- **测试**：新增 `CYAppNetworkTests/NetworkClientTests.swift`，覆盖刷新成功重试、无协调器、刷新失败、重放仍 401 不循环、业务错误不触发刷新 5 个场景。

#### 2. `CYAppState` 可观察性缺陷
- **位置**：`Sources/CYAppUI/AppState.swift` ~75–91、101–110
- **问题**：`theme`、`language`、`hasCompletedOnboarding` 使用 `@ObservationIgnored` 或计算属性，无法驱动 SwiftUI 刷新。
- **建议**：改为普通可观察存储属性；`language` 通过 `CYLocalizationManager` 变更通知同步。

#### 3. 上传 API 协议与文档不一致
- **位置**：`Sources/CYAppCore/Network/NetworkClientProtocol.swift`、`Sources/CYAppNetwork/Network/NetworkClient.swift`、`README.md` ~306–313
- **问题**：README 示例使用 `fileName`、`paramName`、`additionalParams`，但实现仅支持 `data: Data, mimeType: String`，且硬编码 `withName: "file"`、`fileName: "upload"`。
- **建议**：扩展协议和实现，支持完整 multipart 参数。

#### 4. 核心层仍有大量硬编码中文
- **位置**：`NetworkError.swift`、`ImageLoaderProtocol.swift`、`FormValidator.swift`、`BiometricAuth.swift`、`NetworkClient.swift` 错误文案、`NetworkMonitor.swift`、`AppTheme.swift`、`UserSession.swift` 显示名等。
- **建议**：所有面向用户的字符串改为 `Localizable.strings` key，使用 `.cyLocalized` 读取。

#### 5. 请求去重键对复杂 body 不安全
- **位置**：`Sources/CYAppCore/Network/RequestDeduplicator.swift` ~119–138
- **问题**：`deduplicationKey` 用 `String(describing:)` 拼接 `CYJSONValue`，嵌套对象/数组时可能冲突。
- **建议**：将 body 按 key 排序后编码为稳定 JSON 或做 SHA 摘要。

#### 6. 媒体选择器硬编码中文 + 视频过滤被忽略
- **位置**：`Sources/CYAppUI/Components/MediaPicker.swift` ~126、128、214
- **问题**：弹窗中“拍照”硬编码；`onPicked` 只返回 `[UIImage]`，视频过滤后数据被丢弃。
- **建议**：替换为本地化 key；统一返回 `Data` 或区分媒体类型。

#### 7. `@MainActor` 单例 `nonisolated` 初始化风险
- **位置**：`ToastManager`、`LoadingManager`、`UserSession`、`CYAppState` 的 `nonisolated static let shared` / `nonisolated init`
- **问题**：首次构造可能发生在后台线程，违反 Swift 6 严格并发。
- **建议**：移除 `nonisolated` 或在 App 启动时强制主线程预热。

### 中严重度

#### 8. 核心默认值写死
- 缓存目录名、Keychain service、表单验证默认提示、上传字段名等无法统一配置。
- **建议**：把 `AppConstants` 改为可注入配置，支持 `CYAppConfiguration` 覆盖。

#### 9. Loading 视图重复实现
- `CYBaseView` 与 `CYLoadingOverlay` 几乎复制了同一套脉冲/遮罩代码。
- **建议**：提取 `CYLoadingIndicator` 公共组件。

#### 10. 节流器 `CYThrottler` trailing 定时器叠加
- 连续触发会创建多个 `asyncAfter`，彼此不取消。
- **建议**：维护 `trailingWorkItem` 并在新触发时取消旧任务。

#### 11. 测试依赖全局单例
- `CYAppContainer.shared`、`CYBusinessCodePolicy.shared`、`CYFeedbackConfiguration.shared` 等在测试中被修改后未完全恢复。
- **建议**：`setUp`/`tearDown` 统一重置；或支持注入独立实例。

#### 12. 网络/图片层缺少单元测试
- `CYNetworkClient`、`CYKingfisherImageLoader` 未覆盖。
- **建议**：使用 `URLProtocol` mock 或 Alamofire mock 写测试。

#### 13. macOS 兼容性未验证
- UIKit 组件在 macOS 上空实现，CI 未验证 macOS。
- **建议**：CI 增加 macOS 构建；或明确说明 iOS 优先。

#### 14. Keychain / 缓存错误静默失败
- `KeychainHelper` 保存失败只在 DEBUG 打印；缓存多处 `try?` 写入失败。
- **建议**：返回 `Result` 或抛出错误，使用 `CYLogger` 统一记录。

#### 15. `CYAppNetwork` / `CYAppImage` 未显式声明 `FactoryKit` 依赖
- 通过 `CYAppCore` 间接使用，依赖链不清晰。
- **建议**：在 `Package.swift` 中显式添加 `FactoryKit` product。

#### 16. `CYRemoteImageView` 状态管理冗余
- `retryCount` 未使用；重试前未清除 `error`。
- **建议**：移除 `retryCount`，重试前重置状态。

#### 17. `PrimaryButton` / `SecondaryButton` 未使用 `CYScaledButtonStyle`
- 定义了缩放样式但按钮未应用。
- **建议**：应用 `.buttonStyle(CYScaledButtonStyle())` 并补充触觉反馈。

#### 18. `TypewriterModifier` 未在视图消失时取消任务
- 动画 `Task` 在视图消失后继续执行。
- **建议**：使用 `.task` 或 `onDisappear` 取消。

### 低严重度

19. `.gitignore` 未包含 `.swiftpm` 和 `.DS_Store`，建议更新并清理。
20. `CI` 只跑 macOS 原生编译，未验证 iOS 模拟器/ExampleApp。
21. `README.md` 上传示例与实现不一致，需同步。
22. `Route.swift.example` 未使用，建议删除或改为可编译示例。
23. `Date+Extensions` 每次创建 `DateFormatter`，建议缓存或静态格式化器。
24. `CYLogger` subsystem 在 SPM/测试目标可能回退为固定字符串，建议可注入。
25. `CYAppState.reset()` 会重置主题和语言，建议拆分为“重置用户”和“重置所有偏好”。

---

## 4. 下阶段开发方案

### Phase 1：阻塞项修复（1–2 周）

| 任务 | 预期产出 | 验收标准 |
|---|---|---|
| 修复 401 无限重试 | 网络层不再循环刷新 | 单测覆盖：无 refreshToken、刷新失败、重放仍 401 三种情况 |
| 修复 AppState 可观察性 | 主题/语言/引导完成状态能驱动 UI | 示例中切换主题/语言实时刷新 |
| 补齐上传 API | 支持 `fileName`、`paramName`、`additionalParams` | README 示例可编译运行；multipart 字段正确 |
| 核心层全量本地化 | 新增/补全 `Localizable` key | 切换语言后 NetworkError/FormValidator/Biometric 等文案全变 |
| 修复去重键 | 稳定、唯一的 key | 复杂 body 单测通过；无冲突 |
| 修复媒体选择器 | 无硬编码中文；视频过滤行为正确 | 弹窗、Alert 使用本地化；视频可被选择或明确限制 |
| 清理工程文件 | 更新 `.gitignore` | 无 `.DS_Store`、`.swiftpm`、`.build` 等用户/构建产物进入仓库 |

### Phase 2：增强与测试（2–3 周）

| 任务 | 预期产出 | 验收标准 |
|---|---|---|
| 提取公共 Loading 视图 | `CYLoadingIndicator` | `BaseView` 与 `LoadingOverlay` 复用 |
| 修复 CYThrottler | 节流器行为稳定 | 连续触发 trailing 只执行一次 |
| 核心配置可注入 | 缓存目录、Keychain service、验证文案可配置 | 业务方无需改源码 |
| 网络/图片/权限/持久化测试 | 测试覆盖率 70%+ | 覆盖 401 重试、Token 刷新、上传/下载、Kingfisher、权限状态、SwiftData CRUD |
| 测试隔离全局状态 | reset/注入机制 | 测试可并行，不依赖共享单例 |
| macOS 兼容验证 | 可编译/运行 | CI 增加 macOS 构建；ExampleApp 在 macOS 可进入主界面 |
| Keychain/缓存错误处理 | 错误可感知 | 失败返回错误或日志；Keychain 增加 accessibility |

### Phase 3：生态与文档（1–2 周）

| 任务 | 预期产出 | 验收标准 |
|---|---|---|
| 补齐更多业务组件 | 导航栏、图片轮播、图表、表单等 | 有 Preview、单测、文档 |
| 示例工程完整演示 | 登录/列表/详情/设置/持久化示例 | 新用户 5 分钟跑通完整流程 |
| 增强 CI | iOS 模拟器 + ExampleApp 构建 | CI 绿，包含 iOS 模拟器构建 |
| SwiftData 迁移示例 | 版本化迁移计划 | 演示 V1 → V2 迁移 |
| 性能基准 | 缓存/网络/序列化性能测试 | 有基础性能报告，防止退化 |
| 生成 API 文档 | DocC 托管 | 所有 public API 有 DocC 注释 |

---

## 5. 关于是否立即提交到主分支

**建议：可以提交当前优化，但需同步发布“已知问题”说明。**

当前代码已经：
- 修复了多个高风险的可见性 bug；
- 补齐了 DI 按需注册和组件库；
- 通过 `swift build` 和 `swift test`（98 个测试）。
- 已修复 401/Token 刷新无限重试问题，并新增 `CYAppNetworkTests` 覆盖。

仍存在 **AppState 可观察性、上传 API 不一致、核心层硬编码中文** 等高风险问题。如果主分支要求“可用即合”，本次修改可以上传；如果主分支要求“生产可用”，建议先完成 Phase 1 的阻塞项后再合并。

---

## 6. 附录：本次修改的文件清单

### 新增文件
- `Sources/CYAppCore/Image/CYDefaultImageLoader.swift`
- `Sources/CYAppDesignSystem/Components/InputComponents.swift`
- `Sources/CYAppDesignSystem/Components/ListComponents.swift`
- `Sources/CYAppDesignSystem/Components/OverlayComponents.swift`
- `Sources/CYAppDesignSystem/Components/BadgeAndTag.swift`
- `Sources/CYAppNetworkTests/NetworkClientTests.swift`

### 修改文件
- `Package.swift`
- `Sources/CYAppNetwork/Network/NetworkClient.swift`
- `ExampleApp/Sources/ExampleApp.swift`
- `Sources/CYAppCore/DI/FactoryContainer.swift`
- `Sources/CYAppCore/Helpers/AppStorageHelper.swift`
- `Sources/CYAppCore/Helpers/BiometricAuth.swift`
- `Sources/CYAppCore/Managers/AlertManager.swift`
- `Sources/CYAppCore/Managers/LoadingManager.swift`
- `Sources/CYAppCore/Managers/ToastManager.swift`
- `Sources/CYAppCore/Mock/MockLoadingManager.swift`
- `Sources/CYAppCore/Permissions/NotificationPermission.swift`
- `Sources/CYAppCore/Permissions/PermissionProtocol.swift`
- `Sources/CYAppCore/Resources/Localizable.strings`
- `Sources/CYAppCore/Resources/Localizable.zh-Hans.strings`
- `Sources/CYAppCoreTests/AppCoreTests.swift`
- `Sources/CYAppDesignSystem/Components/BaseView.swift`
- `Sources/CYAppDesignSystem/Components/Components.swift`
- `Sources/CYAppDesignSystem/Components/PaginatedListView.swift`
- `Sources/CYAppDesignSystem/Components/ShimmerView.swift`
- `Sources/CYAppDesignSystem/Theme/AppColors.swift`
- `Sources/CYAppPersistence/PersistenceController.swift`
- `Sources/CYAppUI/Image/RemoteImageView.swift`
- `Sources/CYAppUI/Managers/AlertManagerView.swift`
- `Sources/CYAppUI/Onboarding/OnboardingView.swift`
- `Sources/CYFeedbackStyle/FeedbackConfiguration.swift`

---

*本报告由 OpenCode 生成，后续开发可按 Phase 1 → Phase 2 → Phase 3 顺序推进。*
