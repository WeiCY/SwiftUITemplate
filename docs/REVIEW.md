# 项目评测快照

> 评测日期：2026-08-13
>
> 评测范围：`Package.swift`、7 个 Library target、测试、`ExampleApp`、README、DocC、SwiftLint 与 GitHub Actions。
> 验证结果：`swift build` 通过；`swift test` 通过 **98/98**（macOS 14.0，约 2.0 秒）。工作区在评测开始时无未提交变更。

> **注意**：本文件为静态代码审查快照，仅反映评测时点的状态。后续改进计划请查看 [ROADMAP](./ROADMAP.md)，已发布变更请查看 [CHANGELOG](../CHANGELOG.md)。

---

## 1. 结论摘要

项目已经具备作为 iOS SwiftUI 工程模板投入使用的基础：模块边界清晰，核心服务以协议和 Factory DI 暴露，网络、图片和持久化实现可选引入，Swift 6 编译与现有 98 项单元测试均通过。

当前不建议把它定位为"生产就绪的通用基础库"。主要差距不在组件数量，而在依赖声明的正确性、失败可观测性、测试覆盖的均衡性，以及 iOS 端到端 CI 验证。优先完成 P0/P1 后，再扩展组件或迁移测试框架更合适。

**综合评分：8.0 / 10**（评分以当前源码与本次验证为准，不与历史版本机械比较。）

| 维度 | 评分 | 依据 |
|---|---:|---|
| 架构与模块化 | 8.5 | 7 个 Library + 1 个 Example 可执行 target；Core、Network、Image、UI、Persistence 分层明确。 |
| 代码质量与并发 | 8.0 | Swift 6、`@Observable`、actor 缓存、Token 刷新协调器等实现扎实；仍有错误吞没与少量全局状态。 |
| 可测试性 | 7.5 | 98/98 通过，覆盖 Core、UI、401 重试与设计系统；图片、权限、SwiftData、上传/下载与拦截器链仍缺测试。 |
| 可配置性与复用 | 7.5 | 网络、反馈、图片加载可注入；常量、缓存路径、Keychain 可访问级别和日志 subsystem 尚不能统一配置。 |
| 文档与示例 | 7.5 | README 覆盖主要接入路径，Example 可编译；模块数量和部分文档索引仍有不一致，示例覆盖不完整。 |
| CI 与交付质量 | 7.0 | macOS build/test/lint 已配置；未验证 iOS Simulator，lint 依赖 Homebrew 在线安装。 |

---

## 2. 本次核验结果

| 项目 | 结果 | 说明 |
|---|---|---|
| SPM Debug 构建 | ✅ 通过 | 7 个 Library 与 `ExampleApp` 均参与本次构建。 |
| 单元测试 | ✅ 98/98 通过 | Core 68、HighPriority 10、Network 5、UI 8、DesignSystem 5、FeedbackStyle 2。 |
| GitHub Actions | ⚠️ 静态核验 | macOS 15 上执行 `swift build`、`swift test`、`swiftlint lint --strict --quiet`；本次未远程触发 Actions。 |
| iOS Simulator / App UI 测试 | ❌ 未覆盖 | 当前 CI 与本次 SPM 测试均为 macOS 宿主构建，不能替代 iOS 真机或模拟器验证。 |
| SwiftLint | ⚠️ 未在本地运行 | 本机未确认 SwiftLint 可用；CI 通过 `brew install swiftlint` 安装。 |

构建告警（不阻断）如下：

1. Kingfisher checkout 有未声明处理的 `Sources/Info.plist`。
2. `CYAppState.init` 调用 `localizationManager.restore()` 时忽略了返回值，触发编译器 `no-usage` 告警。

---

## 3. 优先问题与建议

### P0：本次已处理

#### 1. `FactoryKit` 是直接使用却未直接声明的依赖

- **位置**：`Sources/CYAppNetwork/AppConfiguration.swift`、`Sources/CYAppImage/ImageLoader.swift`、`Package.swift`
- **证据**：两个 target 都 `import FactoryKit`，但 `Package.swift` 只在 `CYAppCore` target 声明 `.product(name: "FactoryKit", package: "Factory")`。
- **影响**：当前可能借由 Core 的传递依赖编译通过，但 target 的真实依赖不透明，未来依赖图调整或不同构建环境中有构建风险。
- **处理结果**：已为 `CYAppNetwork` 与 `CYAppImage` 分别显式加入 `FactoryKit` product 依赖；本次构建通过。

#### 2. Keychain 与缓存写入失败不可被调用方感知

- **位置**：`Sources/CYAppCore/Helpers/KeychainHelper.swift`、`Sources/CYAppCore/Cache/CacheManager.swift`
- **证据**：Keychain 的 save/delete/read 不返回状态；缓存目录创建、序列化、磁盘读写和删除广泛使用 `try?`。
- **影响**：用户登出、Token 持久化或缓存更新失败时，上层无法降级、重试或上报；问题很难在生产环境定位。
- **处理结果**：Keychain 的 save/delete/read 新增 `Result` API，save 支持可选可访问级别；缓存的 save/remove/clear 返回 `Result` 并记录失败日志；默认认证服务会记录 Keychain 写删失败。

### P1：本次已处理

#### 3. 测试覆盖集中于 Core，关键 I/O 路径薄弱

- **证据**：98 项中 Network 仅 5 项，集中验证 401 刷新/重试；`CYAppPersistence`、权限与图片 target 没有对应测试 target；上传、下载、超时、请求/响应拦截器没有专门验证。
- **处理结果**：`CYNetworkClient` 现可注入 Alamofire `Session`；新增 URLProtocol 测试覆盖请求/响应拦截器、multipart 上传与下载，并新增 SwiftData 内存 Repository CRUD 测试。权限和图片的系统 API 行为仍建议在 iOS UI/集成测试覆盖。

#### 4. CI 未覆盖 iOS 目标，且 lint 安装不够可复现

- **位置**：`.github/workflows/ci.yml`
- **影响**：`#if canImport(UIKit)`、SwiftUI 生命周期、照片/权限桥接以及 ExampleApp 在 iOS SDK 上的编译状态都未验证；每次 CI 现场 `brew install` 也会引入网络与版本波动。
- **处理结果**：CI 新增 iOS Simulator `xcodebuild build` job，构建 `ExampleApp` 且关闭签名。SwiftLint 工具版本固定仍列为后续工程化优化。

#### 5. 文档存在明确的不一致与索引范围错误

- **README**：开头写"按需引入四个库"，表格实际列出 7 个库。
- **DocC**：`CYAppCore.md` 列出 `CYAppConfiguration`，该类型实际属于 `CYAppNetwork`；并称 Core "仅依赖 Foundation + Factory"，应表述为"Foundation + FactoryKit"。
- **历史报告**：此前关于"README 已更新测试数量"的表述不准确；README 仍写 Core "70+ 用例"，当前实际是 78 项 Core + HighPriority 测试，虽然不影响接入，但不宜继续作为精确数量宣称。
- **处理结果**：README 已统一为 7 个库，并更新测试 target 说明；Core DocC 明确 FactoryKit 依赖并移除实际属于 Network target 的 `CYAppConfiguration` 索引。Network/Image/Persistence 独立 DocC 入口仍可作为后续文档完善项。

### P2：本次已处理（前两项）

1. **核心默认值可配置**：新增 `CYAppConfigurationValues`，可在启动时注入缓存目录、Keychain service、分页、动画、Toast 和上传限制默认值。`CYCacheManager` 与认证服务已读取该配置。
2. **AppState 重置语义拆分**：新增 `resetUser()`（保留偏好）与 `resetAll()`（清除用户与偏好）；旧 `reset()` 保留为已弃用兼容入口。
3. `CYAppContainer.shared`、`CYFeedbackConfiguration.shared` 与 `CYBusinessCodePolicy.shared` 等可变单例增加测试顺序/并行风险；建议提供 reset-for-testing 或实例化配置上下文。
4. `ExampleApp` 已演示 Toast、Loading、路由和语言切换，但没有展示主题切换、图片、持久化、登录与错误重试；应补充可运行的设置/收藏页。
5. `Route.swift.example` 没有加入可执行 target；应改成实际示例、迁入文档，或删除以避免过期。

---

## 4. 复用性与平台适用性

| 能力 | 评价 | 说明 |
|---|---|---|
| 协议驱动 DI | ✅ 强 | Network/Auth/Analytics/反馈/主题/语言/图片等可替换，便于宿主接入。 |
| 模块按需引入 | ✅ 强 | Network、Image、Persistence 均为独立 target；需修正显式依赖声明。 |
| SwiftUI 状态与导航 | ✅ 良好 | `@Observable` + `NavigationStack` + 多 Tab Router，符合当前平台实践。 |
| iOS 能力封装 | ✅ 良好 | Keychain、生物识别、权限、网络状态、深链接、媒体选择等覆盖面充足。 |
| 多平台承诺 | ⚠️ 有限 | package 声明 macOS 15，但 UI/UIKit 条件分支与 CI 没有 macOS/iOS 矩阵验证；应注明 iOS 优先、macOS 需验证。 |
| 生产可观测性 | ⚠️ 待加强 | 存储和缓存异常缺少结构化反馈，性能与安全基线尚未建立。 |

---

## 5. 发布建议

**结论：可作为内部模板或 1.0.0 基线使用；不建议在修复 P0 前宣称为通用生产级 SDK。**

本次构建与全部 98 项测试均已通过，当前没有发现阻塞性编译或测试失败。发布前至少应补齐直接依赖声明并让 Keychain/缓存失败可被观测；随后用 iOS Simulator CI 验证真实目标平台。

---

*本报告为 2026-08-13 的静态代码审查与本机构建/测试快照。第三方服务、真机权限行为、远程 CI 运行结果和运行时性能未在本次评测中执行。*
