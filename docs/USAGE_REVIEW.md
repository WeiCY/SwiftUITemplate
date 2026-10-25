# 实际使用与规范复核（2026-10-25）

基线：主分支 `d678504`，包含 10 月 23 日网络可靠性修复及最小 App 生成器。
范围：Package/锁文件、Core 工具与权限/状态、设计系统、媒体/图片、示例装配与已有测试。
这是源码复核与局部修复；不是所有模块的运行验收，也没有核对上游最新 tag 或执行第三方漏洞扫描。

## 总体判断

Swift 6、Observation、MainActor/actor、SwiftUI 原生导航、协议与初始化注入、按 Product 选择实现的方向符合现代项目实践。
目前主要问题是少数通用工具的默认行为、跨线程边界和组件边界输入，而不是缺少新的架构框架。
建议保留七个 Library，在现有边界内逐项收紧契约。XCTest 本身没有过时，不必为了形式统一改写所有测试。

## 已修复的具体使用问题

### Toast 的配置不能导致崩溃

位置：`Sources/CYAppCore/Managers/ToastManager.swift`。

原来 queue 模式在容量为 0 或负数时执行 `queue.removeFirst()`，空队列会崩溃；运行中缩小容量也不裁剪已有积压。
现在非正容量禁用排队、保留当前提示，缩小容量立即丢弃最旧待展示消息。非有限 duration 回退到 2 秒，避免把 NaN/Infinity 传入 Duration。

删除了文档中并不存在的 Toast action/performAction 说明；可操作消息用 Snackbar。
API 名称不变，新增明确的边界语义。新增 4 项回归覆盖零/负容量、缩容、禁用队列和非有限时长。

### 缓存要允许系统清理目录

位置：`Sources/CYAppCore/Cache/CacheManager.swift`。

旧实现只在初始化时尝试创建根目录并忽略错误；目录随后被系统清理时，无 namespace 的 save 无法恢复。
现在磁盘操作统一确保目标目录存在，创建错误通过已有 `CYCacheError.fileSystem` 返回；构造函数不再执行静默失败的磁盘创建。
过期清理仅定位原 namespace，不会在解析目录失败时回退删除根 namespace 的同名缓存。

新增 2 项回归：模拟系统删除后写入并由新实例从磁盘读回、文件阻挡目录时返回错误且不覆盖文件。
仍不提供跨进程事务；目录在检查与写入之间再次被删除时允许返回失败。

### Analytics 默认实现必须诚实且有资源边界

位置：`Sources/CYAppCore/Services/AnalyticsService.swift`。

原来注释声称“批量发送”，实际 flush 只丢弃队列；事件无限积累，identify/track 日志包含用户标识和任意属性，且 Logger 使用 public 隐私级别。
现在默认最多保留 100 个事件，超限丢弃最旧项；可通过 `maxPendingEvents` 配置，非正值不保留事件。
日志只输出固定操作名与计数，不记录用户标识、事件/页面名称、属性或 traits。
默认实现仍是内存缓冲示例，不持久化、不上传；生产分析服务由宿主实现协议并注入。
移除了此实现中不必要的 `@unchecked Sendable`，由编译器检查不可变字段和锁容器的 Sendable 约束。

新增 2 项回归覆盖并发事件容量、清空与重新入队，以及禁用缓冲。
容量限制的是事件数，不是每个属性的字节数，不应向分析事件放入图片或巨大正文。

## 高优先级修复更新

下表四项 P1 已完成代码修改：定位主 actor/共享等待、网络主 actor/代次隔离、日志全局默认与 private、Core 隐私清单。
**Swift 编译、真机和归档验收仍待执行**；使用变化与清单用途限制见 [PLATFORM_BOUNDARIES](PLATFORM_BOUNDARIES.md)。
下表保留原发现作为修复动机。P2 的动画/布局/媒体缓存已完成本轮局部修复，范围、保留限制与未验收项见 [组件生命周期](COMPONENT_LIFECYCLE.md)。

## 原发现与后续优先级

| 优先级 | 位置与证据 | 使用影响 / 建议 |
|---|---|---|
| P1 | `Permissions/LocationPermission.swift`：公开非隔离 init 创建 CLLocationManager；单 continuation；delegate 对 notDetermined 也恢复 | 初始化线程与 run loop 没有保证；首次未决定回调可能提前结束请求，并发调用者直接收到 notDetermined。下一轮统一 MainActor 驱动、忽略非终态回调、定义并发等待和取消策略；须加驱动替身测试及真机授权验收 |
| P1 | `Helpers/NetworkMonitor.swift`：Observable + unchecked Sendable，四个 public 可写状态未隔离，仅内部回调切 MainActor | 外部跨线程访问不受保护；stop/restart 后已排入 MainActor 的旧回调可能覆盖新状态。建议 MainActor + 只读状态 + 监听代次，列为源码兼容性迁移，而不是直接给整个 Core 加 MainActor |
| P1 | `Logger/Logger.swift` 与 `Configuration/AppConfig.swift`：Bootstrap 只改 shared 的级别，network/cache/category 各有自己的级别锁 | 宿主 minimumLogLevel 不能代表全部分类。需要明确全局默认级别与局部覆盖规则；日志默认 public，业务调用也要避免记录任意模型/凭证 |
| P1 | Core 未有包级 PrivacyInfo，使用 UserDefaults、systemUptime、磁盘空间等 API | 按实际用途核对 Required Reason API 并检查归档资源；生成宿主里的初始偏好声明不能覆盖整个库 |
| P2 | `Components/ShimmerView.swift`：phase 在父 modifier 的 State，只在出现时设为结束值 | 关闭再开启 shimmer 可能不重新形成动画；建议使用随条件创建的独立动画子视图或 PhaseAnimator，验证往返与减弱动态效果切换 |
| P2 | `Components/LoadingIndicator.swift`：reduceMotion 只在 onAppear 中决定脉冲 | 运行中切换辅助功能设置不会同步停止已有动画；应让动画由环境值驱动 |
| P2 | `Components/ShimmerView.swift`：公开可变 lineCount/cardCount 直接形成 `0..<count` | 负数会触发非法 Range；需要消费时归一化，且覆盖构造后修改属性 |
| P2 | `Components/FlowLayout.swift`：显式 infinity proposal 原样返回；以 unspecified 测量子项且固定从左布局 | 需验证无限宽提议、长标签、最大字号和 RTL；布局缓存只在测量证明必要后加入 |
| P2 | `Onboarding/OnboardingView.swift`：固定按钮高度、完成按钮文字用 background 而非 onPrimary，页面无滚动 | 长文案/最大字号可能挤出屏幕，品牌色对比不统一；应与基础按钮一致，按可用高度允许滚动，补 VoiceOver 和页面索引语义 |
| P2 | `Components/MediaPicker.swift`：系统选取后用 try? 忽略导入错误；`MediaTypes.swift` 用 Data(contentsOf:) 读整个视频 | 失败可能表现为少选/空结果，大视频可能有内存峰值；优先提供逐项错误结果与文件 URL 上传路径，保留便利接口但写清限制 |
| P2 | `Cache/CacheManager.swift`：NSCache 自动淘汰与 memoryKeyIndex 不同步、缺磁盘容量清理 | 大量不同 key 的长运行 App 仍可能积累索引和磁盘文件；按真实缓存负载补容量与清理策略，缓存不用于永久业务存储 |

P1 表示下轮优先处理的可靠性/发布边界，不表示本轮已经修复。需要改变公开 actor 隔离或返回语义的项目应带迁移说明一起做。

## 第三方库与选择规范

锁文件目前为 Alamofire 5.12.0、Kingfisher 8.11.0、Factory 3.3.2。这里只描述当前锁定版本，不声称它们是最新版本。

| 库 | 建议 | 理由与使用边界 |
|---|---|---|
| Alamofire | 保留可选适配层，不立刻重写 URLSession 版本 | 已有上传、解码、恢复协调及回归测试；更换实现必须先证明依赖成本大于维护收益。无 HTTP 的宿主不选择 Network |
| Kingfisher | 仅需要缓存/预取等能力时选择 | Core 已有默认 URLSession 图片加载；当前 Data 协议可能增加序列化/解码成本，大图性能要先在 iOS 测量再改公共协议 |
| Factory | 暂时保留，但只在组合根使用 | 业务 ViewModel 用初始化注入所需协议，避免引入 @Injected/shared 后又宣称可独立测试。Core 目前仍强制依赖 Factory，真正极简工具包是后续可选目标 |
| SwiftData | 保留系统方案，模型/迁移归宿主 | 使用抛错 create 工厂和可恢复错误页；不要自动删库或用内存库伪装恢复成功 |
| SwiftUI | 原生 NavigationStack/TabView/safeAreaInset 优先 | DesignSystem 提供品牌与有明确价值的组件，避免重建系统导航、键盘、分栏抽象 |

SPM 的 `from` 表达兼容版本区间，不等于每个 App 永远固定同一个版本。宿主应提交自己的 Package.resolved，升级依赖时评审 release notes 并跑宿主测试。
Product 不参与链接不代表其第三方包不参与解析；是否拆分适配包以真实建项目耗时和离线需求为依据。
本轮没有新增或升级第三方库，也没有为追求“现代化”引入 TCA、RxSwift 等新的状态框架。

## 实际验证与限制

- 新增 `UsageSafetyTests.swift` 的 8 个 XCTest，覆盖上述 Core 修复；当前环境没有 Swift/Xcode，尚未执行，不能宣称通过。
- 可执行的 Python 生成器 6 项回归、71 项公开 UI/支撑类型矩阵及 git diff 空白检查通过。
- 本轮未运行 SwiftLint、Swift 类型检查、完整 Package 测试、iOS/macOS 宿主或 UI/真机测试。

macOS 验收命令：

```bash
swift test --filter UsageSafetyTests
swift test
swiftlint lint --strict --quiet
python3 scripts/verify-doc-examples.py
```

组件动画、VoiceOver、定位授权和主线程检查需要相应 UI/设备验收，不能靠测试数量替代。
