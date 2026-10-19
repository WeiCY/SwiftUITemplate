# 变更记录

> 已发布版本的变更记录在下方；尚未发布的进行中变更统一放在 [Unreleased] 小节。未来计划请查看 [docs/ROADMAP.md](docs/ROADMAP.md)。
>
> 版本号遵循 [语义化版本（Semantic Versioning）](https://semver.org/lang/zh-CN/) 规范：`MAJOR.MINOR.PATCH`

---

## 版本历史

### [Unreleased]

#### 组件与扩展复用专项（第三轮，2026-10-19）

- 保留全部前两轮未提交成果及七库结构，不新增第三方依赖。完整组件/扩展分类、真实缺口、原生/Recipe替代和宿主边界写回 MODULE_COMPONENT_REVIEW；不按数量或无标准精确评分判断成熟度。
- 修复 Snackbar 取消的旧计时任务关闭后继消息；动作先关闭再回调，回调显式 MainActor，可重入显示新消息。非法/非正/超范围duration保留到显式关闭；启用原先未消费的dismiss入口，长内容不再固定两行。已有常规初始化调用保持；新增确定性竞争回归、iOS大字体长内容交互和截图。
- Keychain 保存改为按service/account更新、缺失才添加、并发插入再更新一次，返回原status且不主动删除旧值。移除读取失败日志中的account。测试通过内部系统操作桩覆盖更新/添加/竞争/失败；不冒充真机Keychain权限验收。
- 修复 Array.sample负数崩溃和chunk边界加法；Double.formattedAsBytes对非有限/越界数值返回原文本；Color(hex:)拒绝部分成功解析及多#，保留合法RGB/RRGGBB/RRGGBBAA。
- URLRequest.cURL默认使用同一网络日志脱敏，正确shell单引号引用。**行为变化**：默认输出不再含原始凭证/非结构化Body；本地原文需显式cURL(redactingSensitiveData:false)，保留属性入口。
- CYTag新增默认兼容selectedTextColor并表达选中trait；清除/筛选图标补本地化标签和清除触点；目录展示局部前景配色、Snackbar替换并使字体环境覆盖overlay。修正不存在的CYAppState.shared和TagGroup绑定误述。
- ConsumerFixtures的既有OfflinePage新增原生草稿编辑，取消不写入，保存处理错误；CoreOnly验证新边界。接入指南补选择Recipe及三个类型检查示例。
- 移除缓存注释里不可复现的“快2–3倍/缩小50%/按10KB切换”结论，纠正PropertyList嵌套支持。补区域校验、Unicode数字、HTML正则、字段快照语义；标出媒体、OTP、旧导航/键盘/存储包装的具体未解决限制，不批量删除API。
- 本轮实际验证与未验证范围见 docs/ENGINEERING_VALIDATION.md 第三轮记录；前两轮证据文件未覆盖。

#### 模块与组件独立接入（第二轮，2026-10-19）

- 新增 ConsumerFixtures 独立 Package：CoreOnly、OfflinePersistence、NetworkOnly、DesignSystemConsumer、CustomComposition；public API 行为测试、Proof 链接检查和可复用 iOS 宿主进入 CI，不复制框架或依赖 ExampleApp。
- 新增 CYPaginationState 与 CYPaginatedListContent，以值快照 + refresh/loadMore/retry 回调支持宿主 Observable。原 CYPaginatedListView 所有初始化器保留，内部适配同一 renderer；不需要旧消费者迁移。新入口的页码、并发/取消与旧结果隔离由宿主负责。
- CYNetworkClient 新增必传 sessionConfiguration: URLSessionConfiguration 的兼容重载，支持不 import Alamofire 的会话配置；原 session: Session 和默认初始化保持，无破坏性 API 删除或隔离要求变化。
- 组件目录新增全部公开类型搜索与更多组合，UI 自动化图片改用确定性 Loader。新增七模块/76 个公开 UI 与支撑类型矩阵、冷/增量构建与真实链接清单、列表与页面往返内存测量范围。
- 严格 lint 纳入消费者和 Tests；CI 增加文档示例类型检查及公开类型覆盖检查。保留包级第三方解析、启动全局配置等设计限制，最低运行系统/真机/VoiceOver/iOS 大图性能不写成通过。验证详情见 docs/ENGINEERING_VALIDATION.md，迁移示例见 docs/GETTING_STARTED.md。

#### 工程完善（2026-10-18）

- 保留 7 个 Library 与可选 Network/Image/Persistence 分层，未新增应用第三方依赖。
- 主题 apply/saveAndApply、设备 idiom、触觉与键盘 UI 操作明确 MainActor；后台调用需要 await。
- 分页新增 failure(refresh/append(page))、显式 retry 和 reset；失败不跳页，追加失败暂停自动重试，空态可刷新，刷新失败保留数据与元信息。
- Persistence 新增可抛错 create(for:) / create(schema:migrationPlan:configurations:)；旧 fail-fast init 和无迁移作用的版本常量废弃。ExampleApp 增加错误页及重试；磁盘 V1→V2 测试验证旧数据保留。
- Kingfisher 8.11.0 桥接传递 Task 取消，用 Mutex 保证 continuation 一次恢复；网络成功使用 result.data()，缓存路径仍可能序列化。新增实际下载、缓存与取消竞争测试和可复现大图微基准。
- 所有网络日志统一脱敏 URL query、Header 和结构化 JSON；未知 Body 隐藏。终态错误日志只保留错误类型，不再打印可能含秘密的 Error 原文。
- ExampleApp 的 Toast/Loading/Alert 在组合根装配并挂载同实例；Alert 支持存在类型，自定义反馈经模拟器 UI 测试验证。测试支持统一恢复配置、Factory 注册和两层缓存。补查原始 HEAD 的 19 项 lint 违规并局部修复，不关闭规则。
- 新增本地 Package 的 ExampleApp.xcodeproj，复用原有 Sources/@main，区分 Bundle.module 与 Bundle.main；加入原生回归/UI 测试及实际 CI 宿主构建/运行步骤。
- 新增组件目录、表单、搜索分页与媒体组合示例；支持深浅色、大字体、长文案与启动第二品牌。主要操作补按钮语义和标签，动效尊重减弱效果及生命周期取消。
- CYDesignConfiguration/CYDesignTokens 统一启动品牌、配套前景色、动态字体、间距、圆角与控件尺寸；旧颜色/字体/尺寸读取方式保留，不保证运行时换品牌刷新。
- 修复 truncated 非正长度、日期缓存维度、MultiDateDecoder 并发、typewriter 重播、shake/pulse 生命周期；新增抛错 Decodable.decode 入口及 retry/withTimeout 参数和取消边界。
- 文档修正 Codable 运行时解码错误、class 管理器、字体配置、持久化/迁移、反馈挂载、路由/Sheet/Deep Link 和真实网络切换。详细验证见 docs/ENGINEERING_VALIDATION.md。
- 验证：基线 macOS 185 测试；本轮 macOS 214 测试、iOS 28 原生回归和 5 UI 测试通过；Package 全测试交叉编译、宿主构建、5 个关键文档示例类型检查通过。SwiftLint 0.59.1 严格检查通过；工具链输出与未验证范围见工程验证记录。

##### 最小迁移

```swift
// 原 CYPersistenceController(for:) 失败终止进程；现在由宿主捕获并展示重试
let store = try CYPersistenceController.create(for: [HostModel.self])
// 版本化宿主传 Schema(versionedSchema:)、migrationPlan 和 configurations

// 后台调用 UI 方法显式跨到 MainActor
await themeManager.apply(.dark)

// 同一组依赖同时传给业务和根视图
RootView()
    .feedbackOverlay(toastManager: toast, loadingManager: loading)
    .alertManager(manager: alert) // feedbackOverlay 不含 Alert
```

`CYAppFont.*` 仍只读，改用启动时 `CYDesignConfiguration.configure(tokens)`。
`Decodable.from` 的 nil 行为保持，想保留错误使用 `try Model.decode(jsonString:)`。
`CYPaginatedListViewModel.retry()` 现在按失败类型重试；追加失败后需显式调用，不再靠行 onAppear 重试。
`withTimeout` 对非正/非有限秒数抛 invalidInterval，仍是协作式取消；Task.retry 的 times 为总尝试次数。


#### 稳定性修复（2026-10-13）

- 修复 `CYAppState.language` 不通知 Observation；切换与重置语言同步到可观察状态
- Core 与 ExampleApp 本地化资源改为 `en.lproj` / `zh-Hans.lproj`；模板文案按选定语言读取，示例界面文案迁入宿主资源
- `CYLocalizationManager` 新增可注入 `bundle` / `defaults` / `systemLanguages` 的初始化与指定资源包的 `localized` 重载
- 分页请求增加代次校验，防止刷新后混入旧分页数据/错误；刷新失败保留分页元信息，取消不展示错误
- `CYBaseViewModel` 忽略旧任务的 loading/error 收尾，成功后不保留过期重试闭包
- 缓存键与 namespace 改用 SHA-256 文件名，nil/空 namespace 统一；缓存格式升级到 v2，旧缓存自然失效
- 去重键采用结构化稳定编码，覆盖 query/body/headers/authentication，Encodable 指纹使用端点编码策略；任务按结果类型及登记身份隔离
- 自定义权限注册不再被首次默认注册覆盖
- HTTP 204/205 空响应直接返回 `CYEmptyResponse`，不依赖业务成功码包含 0
- 响应拦截器终态执行一次，拦截器错误不触发成功请求重放；下载成功分支不再吞掉拦截器错误
- 远程图片按 URL 重置状态，旧加载结果不能覆盖当前资源，nil URL 显示占位/空内容
- 防抖与节流的全部可变状态受锁保护，调用方 action 在锁外执行
- 系统媒体选择器支持视频 FileRepresentation 导入；新增 `CYMediaItem(videoURL:)` 与 `videoURL`，导入副本随媒体项生命周期清理
- ExampleApp 批量删除采用对象快照并统一保存/刷新；TabView 双向绑定 Router 的选中 Tab
- 新增 ExampleApp 测试目标与 Observation、分页交错、去重碰撞/取消、缓存隔离、本地化、工具并发、图片身份和视频文件生命周期回归测试
- 验证：macOS 185 个测试全部通过；iOS Library / ExampleApp / 测试目标交叉编译通过；iPhone 17（iOS 26.5）模拟器的 2 个视频文件生命周期测试通过

#### ExampleApp（一致性收尾）

- `ArticleService` 移除默认参数，改由组合根显式注入，不再引用 Legacy Facade `CYAppContainer.shared`
- 新增 `AppDependencies` 组合根；`HomeView` / `BookmarkView` 改为接收注入的 ViewModel
- 长期文档（`README` 等）不再写死测试数量，统一引用 CHANGELOG

#### 文档

- 统一当前主干 / Unreleased 与已发布 tag 的文档适用边界
- 接入指南补完整视频调用示例与文件所有权、默认/自定义本地化读取入口说明
- 网络指南校准响应链路顺序、204/205 与业务成功码边界、终态拦截器错误规则
- ROADMAP 同步已完成回归与模拟器文件测试，区分真实相册/真机待验收项；工具链描述与 CI 实际选择对齐
- DocC 移除过期认证 Mock/权限/本地化符号，补 URLSession 默认图片实现、宿主业务边界；架构目录树与当前 Sources/ExampleApp 对齐

- 收敛文档结构：旧 `REVIEW` 与 `NETWORK_REFACTOR_PLAN` 归档至 `docs/archive/`；新增轻量 [docs/REVIEW.md](docs/REVIEW.md)（1.2.x 评测结论，随版本更新）
- `APP_FACTORY_GUIDE` 内容合并进 `TEMPLATE_RULES`（模块选择 / 宿主目录 / 新 App 工作流 / 边界 / 验收清单）与 `README`，移除独立文件
- `ROADMAP` 更新 1.2.0 状态，删除与 `TEMPLATE_RULES` 重复的开发流程章节
- `GETTING_STARTED` 网络章节收敛并链接 `NETWORK_GUIDE`，修正过期的 Mock 示例
- `GETTING_STARTED` 与 ExampleApp 对齐：Service / ViewModel / View 改为显式初始化注入，新增 Composition Root 说明，移除 `CYAppContainer.shared` 作为新代码推荐写法
- 仓库链接统一为 `https://github.com/WeiCY/SwiftUITemplate`；`ExampleApp` 定位统一为“接入范例”
- `ARCHITECTURE` 补充 Composition Root 结构与 DI 能力映射（Base DI / `NetworkProviding` / Legacy Facade）
- `TEMPLATE_RULES` 明确永久边界清单，新增“AI / Agent 修改规则”
- `ROADMAP` 删除业务语义测试目标与未经验证的组件规划，改为真实需求驱动，并移除未来版本预测数字
- `REVIEW` 改为 App Factory 评价视角，明确当前无 P0 阻塞问题

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
