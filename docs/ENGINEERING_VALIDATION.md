# 工程验证记录

日期：2026-10-18；主干 Unreleased。Xcode 26.5 (17F42)，Swift 6 模式，arm64 macOS；iOS 26.5 的 iPhone 17 模拟器。未提交、推送、打 tag 或发布。

以下至“第二轮”章节前为第一轮历史记录；其中空工作区、185 基线等描述不代表第二轮输入。第二轮以第一轮全部未提交/未跟踪成果为输入，基线为 214 测试。

## 基线与分阶段验证

工作开始时 git status 为空，没有覆盖用户修改。当前目录及祖先没有适用 AGENTS.md；已阅读模板规则和当前文档。先核实已有修复：分页代次、图片 URL 身份、视频文件所有权等保留，不重复重构。

| 阶段 | 结果 |
|---|---|
| 基线 | macOS 185 个测试通过 |
| 一：稳定性 | 196 个 macOS 测试通过；iOS Package 编译通过，指定 UIKit 源码 actor 警告消失 |
| 二：DI | 198 个测试通过，注入同实例和持久化恢复回归 |
| 三：宿主与组合 | 200 个测试通过；Xcode 宿主无签名构建通过 |
| 四：品牌与工具 | 207 个测试通过 |
| 五：整体验证 | macOS 214 个测试通过；iOS 28 个原生回归、5 个 UI 测试通过；5 个文档示例独立类型检查通过 |

## 已执行命令与结果

- `swift build --disable-sandbox`：通过。
- `swift test --disable-sandbox`：214/214 通过。
- iOS Package / ExampleApp / 全部测试目标交叉编译：`swift build --build-tests --sdk <iphonesimulator SDK> --triple arm64-apple-ios18.0-simulator -Xlinker -syslibroot -Xlinker <SDK>` 通过。
- `xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`：通过。
- 同 Scheme 在 iPhone 17 (iOS 26.5) 执行 test：原生回归 28/28、UI 5/5 通过。Scheme 将两类测试分开报告。
- `python3 scripts/verify-doc-examples.py`：5 个关键示例通过。它检查 README 最小 App，以及反馈存在类型、品牌配置、分页、Router Sheet 的 Swift 6 类型正确性；不是所有说明性片段的完整宿主生成器。
- SwiftLint 0.59.1：`swiftlint lint --strict --quiet --no-cache` 通过（零违规）。工具从官方固定版本下载到 /tmp，并完成 ZIP 完整性校验；未增加应用依赖。补查原始 HEAD 有 19 项既有 lint 违规，本轮以局部修改修复，没有关闭规则。
- `git diff --check`：通过。

受沙箱限制，将 CLANG_MODULE_CACHE_PATH / SWIFTPM_MODULECACHE_OVERRIDE 定向到 /tmp。首次 Xcode 依赖拉取停滞，改用现有固定版本缓存并禁用自动解析/更新后完成构建。仓库仅记录相对 Package 路径，不记录本机缓存路径。

## 有意义的测试覆盖

- 分页首次失败、追加失败、显式重试同页、不重复追加、刷新失败元信息保留、取消、旧刷新和旧追加响应隔离、搜索条件重置。
- 可注入持久化初始化错误保持原始 NSError；真实磁盘 V1→V2 迁移保留 title；内存 CRUD、收藏批量删除和示例失败页重试。
- 图片提前取消、重复回调、100 次完成/取消竞争、实际 Kingfisher DownloadTask 取消、原始字节与内存缓存、URL 替换、自动失败恢复和包装取消不重试。
- 日志 URL query、敏感 Header、JSON 对象/数组/大小写/转义引号、无法解析 Body 的保守隐藏。
- 同一个注入反馈实例；实际模拟器中自定义 Toast / MockLoading / 自定义 Alert 驱动 UI。
- Factory 的 manager 注册/缓存与 TaskLocal singleton 缓存双层隔离；配置快照恢复到测试前值。
- 字符串 Unicode/非正长度、解码错误上下文、日期时区和日历缓存、重试/超时参数与取消、Token 默认和第二品牌；typewriter 的文本替换、取消、禁用和无效速度。

测试中新增的请求竞争通过 continuation、URLProtocol、expectation 控制，没有靠固定 sleep 推断请求顺序。示例中的防抖/模拟延时是演示交互行为，非测试同步机制。

## 图片适配路径测量

可复现命令：

```bash
swiftc -O scripts/image-adapter-benchmark.swift -o /tmp/cy-image-bench
/tmp/cy-image-bench
```

本机生成 3840×2160 渐变加确定性噪声 JPEG，2,867,056 bytes；先暖身一次，再测 7 次，取中位数。两条路径均强制将结果绘制到 CGContext，避免只测惰性 NSImage 构造。

| 路径 | 中位数 | 交给视图的字节数 |
|---|---:|---:|
| 原实现：NSImage → TIFF → PNG → 视图解码/绘制 | 369.55 ms | 9,836,006 |
| 网络原始数据 → 视图解码/绘制 | 34.41 ms | 2,867,056 |

这是 macOS 上的适配环节微基准，排除了两边共同的 Kingfisher 前置解码、网络和缓存；不是 iOS 整体性能或内存峰值数据，也不能外推到其他图像。Kingfisher 的 `result.data()` 在缓存命中时可能序列化；Data 公共协议仍需要视图解码。没有据此承诺整体性能提升比例。

## 工具链/框架输出与剩余验收

- Kingfisher 8.11.0 的未声明 Info.plist 资源提示属于第三方包。
- SwiftPM 缓存目录不可写、readonly manifest cache 属于执行环境；交叉编译 clang 的 MacOSX sysroot 提示与 AppIntents 无依赖时跳过元数据提取属于工具链输出。Xcode 原生宿主构建不依赖该交叉链接方式。
- Xcode 26.5 仍有 Core→FactoryKit 的 dependency scan 提示；Package.swift 与实际构建图均显式声明 FactoryKit，构建和运行通过。本轮未消除这一扫描诊断，也不把它计作 UIKit actor 警告已清零的依据。
- macOS 沙箱测试可能输出 CoreData 通知注册失败；模拟器 SwiftData 首次打开默认目录可能先输出文件创建/恢复日志。迁移数据断言和 UI 恢复均通过，不能把这些输出说成项目警告已全部清零。
- UI runner 曾被 SpringBoard 以 Busy 拒绝启动；重启测试设备后恢复。表单键盘焦点提交已实际通过；分页开关测试修正了原生子控件定位。
- 未做真机触觉、真实相册/相机交互与视频来源矩阵、真实后端、完整 VoiceOver/最大字号/后台恢复矩阵、生产库迁移和 TestFlight。当前 UI 测试覆盖列表/详情/收藏、主题、自定义反馈、表单键盘焦点提交、首次分页失败重试和存储恢复，不替代完整运行验收。
- 品牌仅保证启动配置；页码分页、图片 Data 接口与协作式超时的限制见接入指南。

## 第二轮：独立模块与组件接入（2026-10-19 交付）

### 工作区、环境与基线

- 开始时工作区已有上一轮大量修改及未跟踪的宿主、脚本、测试和文档，全部作为输入保留；没有 reset/clean、删除用户缓存、提交、推送、tag 或发布。当前目录及祖先没有适用 AGENTS.md。已核对要求列出的全部文档和既有实现，不重复实现上轮修复。
- 初始完整 macOS 测试 214/214；本轮最终仍为 214/214，另外在独立 Package 中增加 7 个 public-only 行为测试，而非用测试数增长代替兼容验证。
- Xcode 26.5 (17F42)，Apple Swift 6.3.2、Swift 6 模式；arm64 macOS **26.6.2 (25G83)**。当前 iPhone 17 模拟器 **iOS 26.5 (23F77)**。本机只有 iOS26.5 运行时，没有 iOS18；macOS15 也没有实际运行环境。
- 包平台仍 iOS18+/macOS15+；编译最低 target 与当前系统运行分别记录。iOS 原生 Scheme 使用 deployment target 18.0；不能把 SDK26.5 上的编译/运行外推为 iOS18 实跑通过。

### 本轮命令与结果

以下命令在仓库根执行。沙箱内 CLI 构建设置 `CLANG_MODULE_CACHE_PATH=/tmp/cy-root-modules SWIFTPM_MODULECACHE_OVERRIDE=/tmp/cy-root-modules`；iOS 交叉编译使用单独 `/tmp/cy-ios-module`。Xcode/simctl 经授权访问模拟器服务和系统缓存。`--disable-sandbox` 指 SwiftPM 构建沙箱，不是关闭系统权限。

| 验收 | 实际执行与结果 |
|---|---|
| Package Debug 构建 | `swift build --disable-sandbox --skip-update` 成功；最终目录元数据改动也重新编译 |
| 完整 macOS 回归 | `swift test --disable-sandbox --skip-update`，214 测试、0 失败，最终约 2.24s 测试执行时间（非构建总耗时） |
| 独立消费者 / 链接证据 | `python3 scripts/verify-consumers.py --cache-from .build --output /tmp/cy-round2-consumer-delivery.json`；五个 Proof 构建/运行、增量构建、实际链接清单和禁止模块检查通过；7 行为测试、0 失败；无 @testable/ExampleApp 内部依赖 |
| 最低 iOS target 全测试编译 | `swift build --build-tests --disable-sandbox --skip-update --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" --triple arm64-apple-ios18.0-simulator -Xlinker -syslibroot -Xlinker "$(xcrun --sdk iphonesimulator --show-sdk-path)"` 成功；是交叉编译，不是运行全部 XCTest |
| 既有 Xcode 宿主 | 最终目录元数据变更后 `xcodebuild ... build` 也成功；ExampleApp Scheme 的 `xcodebuild ... test` 成功：iOS 原生回归 28/28，UI 5/5；含旧分页/输入焦点键盘提交、持久化恢复与既有反馈流程 |
| 独立 Xcode 宿主 | Consumers Scheme 的 `xcodebuild ... test` 成功：UI 3/3；分页首次失败/追加失败恢复、自定义服务/路由挂载、accessibility2 操作与图片退出取消、10,000 行列表/页面往返 |
| 严格 lint | SwiftLint 0.59.1：`swiftlint lint --strict --quiet --no-cache`，零违规；纳入 ConsumerFixtures 和 Tests，没有关闭规则 |
| 文档类型检查 | `python3 scripts/verify-doc-examples.py`，7 个示例通过；新增宿主分页、Foundation Network 配置，既有五个保留；支持当前主机架构，不硬编码 arm64 模块目录 |
| 公开组件登记 | `python3 scripts/verify-component-matrix.py`，76 个 public UI/支撑类型在矩阵与目录中登记，消费者相对路径/公开 API 检查通过；不等同视觉 QA |
| 补丁空白 | `git diff --check` 通过；不代表未跟踪文件已经提交 |

iOS 测试实际命令（两个工程分别执行，避免并发争用同一模拟器）：

```bash
xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp \
  -destination 'platform=iOS Simulator,id=D7961504-06E5-4C70-B37D-EBB8BF39C204' \
  -derivedDataPath /tmp/cy-host-derived -clonedSourcePackagesDirPath /tmp/cy-offline-packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project ConsumerFixtures/Host/Consumers.xcodeproj -scheme Consumers \
  -destination 'platform=iOS Simulator,id=D7961504-06E5-4C70-B37D-EBB8BF39C204' \
  -derivedDataPath /tmp/cy-round2-final-fresh-derived -clonedSourcePackagesDirPath /tmp/cy-offline-packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

设备 ID 只属于本次执行日志，消费者工程和 Package 路径均相对；CI 动态选择可用 iPhone。消费者首次使用全新 `/tmp/cy-round2-consumer-derived`，最后为确认最新 UI runner 又使用另一个全新 `/tmp/cy-round2-final-fresh-derived`。两次都复用已下载固定版本依赖源码，不是首次网络下载验证；没有删除原缓存。

### 构建、依赖解析与 API 兼容证据

机器可读记录：[ConsumerFixtures/Evidence/build-proof.json](../ConsumerFixtures/Evidence/build-proof.json)。测量为 2026-10-18，macOS26.6.2 arm64 Debug、全新 scratch 与 module cache，只复制 repositories/checkouts；按下表顺序共用一个 scratch。**只有首项是所有编译产物均无缓存的冷构建**，后续 first 是该消费者第一次构建，复用之前编译的共用模块。增量为紧接着同一命令。单次采样、有其他工作负载，不做性能提升百分比或跨机比较。

| Proof | first 秒 | 增量秒 | Debug 可执行文件 bytes | 实际链接的框架/第三方模块（另有自身场景/Proof） |
|---|---:|---:|---:|---|
| CoreOnly | 17.519 | 2.024 | 2,641,520 | Core、FactoryKit |
| OfflinePersistence | 3.020 | 1.829 | 2,698,928 | Core、Persistence、FactoryKit |
| NetworkOnly | 5.785 | 1.784 | 6,494,560 | Core、Network、Alamofire、FactoryKit |
| DesignSystemConsumer | 4.262 | 1.876 | 4,707,024 | Core、DesignSystem、FeedbackStyle、FactoryKit |
| CustomComposition | 3.829 | 1.775 | 5,397,712 | Core、UI、DesignSystem、FeedbackStyle、FactoryKit |

上表和 JSON 的对象模块清单只统计模板/第三方 Swift 模块，不含系统框架。另对同一 Debug CoreOnlyProof 执行 `otool -L`，发现 SwiftUI、AppKit、Combine、AVFoundation、Photos、CoreLocation 等系统链接；Core 的权限/平台工具使其并非 Foundation-only。复现时在单产品 build 后对 `$(swift build --package-path ConsumerFixtures --show-bin-path)/CoreOnlyProof` 执行 `otool -L`。不选择模板 UI Product 不代表不链接 Apple UI 框架。

所有场景都没有编译或链接 Image/Kingfisher、ExampleApp、CYTestSupport；未选择的 Network/Persistence 同样排除。完整编译模块与链接模块分列存 JSON：后续首次编译日志里没有 Core，是因为同 scratch 已编译过，不代表最终不链接 Core。根 Package 的 Alamofire5.12.0、Kingfisher8.11.0、Factory3.3.2 **仍全部参与解析**，由消费者 lockfile 与 manifest 佐证；不是零依赖离线包。

本轮仅在框架增加两个分页公开类型及 Foundation 会话初始化重载，未删除旧 API、修改旧签名或新增框架 actor 隔离要求。开工前 public 声明清单与源文件差异检查结合使用；不是稳定 ABI 保证。原 VM 初始化器在独立 LegacyConsumerPage 编译，ExampleApp 搜索流程运行。新状态入口的完整同页重试、刷新保留、取消不报错、旧响应隔离由外部行为测试验证；实际 UI 展示重试/恢复通过。NetworkOnly 直接使用协议与本地桩完成成功/HTTP500/实际 stopLoading 取消，不访问公网。

### 列表、图片与内存测量范围

iPhone17 模拟器、iOS26.5、Debug、10,000 条本地简单 Text 行；XCTClockMetric + XCTMemoryMetric(application:) 三次执行上下滚动、进入图片页、离开/返回、再切回列表。图片为注入的 1×1 GIF，slow Loader 的挂起/取消由计数器验证；它用于确定性生命周期验收，**不是 iOS 大图/解码性能基准**。XCTest 时间包含自动化合成事件和等待，不能换算 FPS 或流畅度指标。

最终一次全新 DerivedData 运行的原始测量见下表（无设定性能基线，因此测试通过不代表性能阈值达标）：

| 指标 | 平均 | 三次原始样本 |
|---|---:|---|
| Memory Peak Physical (CYConsumerHost), kB | 63583.171 | 63605.016, 63555.864, 63588.632 |
| Clock Monotonic Time, s | 8.281 | 8.280985, 8.264725, 8.298418 |
| Memory Physical (CYConsumerHost), kB | -27.307 | -49.152, -32.768, 0.0 |
| Absolute Memory Physical (CYConsumerHost), kB | 63091.651 | 63113.496, 63080.728, 63080.728 |

物理内存单位沿用 XCTest 的 kB；peak 为测量区间峰值，Memory Physical 为区间变化量，Absolute 为报告绝对物理量。原始数据保存于 [ios-ui-measurement.json](../ConsumerFixtures/Evidence/ios-ui-measurement.json)。

三次短循环只能作为后续对比基线，不足以判定没有泄漏；没有 Instruments 长时间分配/引用追踪，没有实机大图、低内存、多图片快速滚动或帧时间测量。上一轮 macOS 图像微基准保留原范围，不作为本轮 iOS 整体性能结论；没有凭外观实施缓存/解码架构优化。

### 失败、诊断与保留验收

- 修复前，外部独立状态消费者调用分页报缺少 viewModel/不支持 items/onRetry；Foundation 会话配置报 `extra argument sessionConfiguration`。新 API 可编译并完成上述行为验收，分别归类 P2 接入阻力。
- 外部 UI 初版追加恢复断言直接找 row20，受 List 虚拟化/滚动位置影响失败；改为宿主可观察 loaded count（明确等待 40/60）后通过，并由行为测试断言请求页码和唯一 ID，未靠放宽业务正确性断言处理。
- 增量 Xcode 运行曾复用较早 UI runner：日志没有最新 Route/Loading 步骤。最终改用另一全新 DerivedData，确认编译测试源及实际操作日志；未删除缓存。不能把旧 runner 的成功当最新测试证据。
- SwiftPM 默认缓存目录不可写导致初次 CLI 构建失败，改 module cache 到 /tmp 后通过；保留 readonly manifest、Kingfisher Info.plist、弃用 skip-update 和交叉链接 sysroot 提示。Xcode26.5 dependency scan 还报告过 Core/DesignSystem 的 FactoryKit/FeedbackStyle 依赖；manifest 与实际图已声明，构建运行成功，未据此修改真实依赖图，也不宣称全部 warning 清零。
- 最低 iOS18/macOS15 **运行未验证**；当前系统运行通过。无真机、VoiceOver 全流程、全部小屏/横屏/分屏/最大字号/减弱动效视觉、真实 Photos/相机/视频/触觉、生产 Schema/后端/认证、iOS 大图/帧率/长期泄漏、TestFlight 验收。
- 品牌/默认反馈样式与模板本地化是进程级；DI 具体工具和高级第三方类型边界继续保留。详细的组件逐项状态、平台和未验收范围见 [MODULE_COMPONENT_REVIEW](MODULE_COMPONENT_REVIEW.md)。

CI 已接入 public-only 消费者构建/测试/链接检查、JSON artifact、公开组件登记/文档类型检查和独立 iOS 宿主。当前为本机执行证据，未推送触发远端 CI，不将配置落地写成远端运行已通过。

## 第三轮：组件与扩展专项（2026-10-19）

### 输入、范围与复现

工作区带前两轮 staged 成果进入本轮，开工前导出index补丁，收尾逐字节比较仍相同；本轮修改留在工作树/新增文件，不移动原index。未reset/clean、提交、推送、发布、增加第三方依赖或创建新App。当前目录和祖先没有适用AGENTS.md。上一轮构建/图片性能JSON保留原文件，不用新运行覆盖历史数字。完整取舍在 MODULE_COMPONENT_REVIEW 的第三轮两个清单。

环境沿用Xcode26.5/Swift6、arm64 macOS26.6.2、iPhone17/iOS26.5模拟器；目标仍iOS18/macOS15。SwiftPM module cache显式/tmp，Xcode两个宿主用独立新DerivedData，复用已下载依赖而非网络更新。模拟器服务、Xcode及xcresult截图导出需要越过文件沙箱访问系统服务/缓存，自动审批通过；没有要求用户手动确认。

先定义预期，再添加回归/修改实现：

| 场景 | 原行为/路径证据 | 修复后的验证 |
|---|---|---|
| Snackbar旧消息计时被取消 | 修复前针对测试实际失败：替换后isPresented=false、message=nil；try? sleep吞取消后仍dismiss | 最终用受控continuation和任务句柄精确等待，连不配合取消的wait也不能关闭新消息；显式dismiss与同轮show、正常到期、非法duration、action显示后继均通过 |
| sample负数 | 修复前独立filtered XCTest进程signal5，Collection.swift报“Can't take a prefix of negative length” | 非正返回[]，空集合/Int.max数量和chunk边界有回归；外部CoreOnly实际调用 |
| Color(hex:)部分解析 | 原12GG56、0x1234、##123456三断言失败，得到有效颜色 | 全串ASCII hex+可选单#，非法clear；合法带空白#红色仍通过 |
| Double字节显示 | 原Int64(self)存在NaN/Infinity/越界转换trap路径；未为此额外启动崩溃进程 | 针对值和Int64上界测试返回原文本、正常1536.9按1536格式化；外部Proof覆盖nan |
| Keychain更新 | 原delete查询含新数据和可访问性，再add；不具备按service/account安全更新语义 | 内部Security操作桩断言定位查询不含新值；更新/缺失添加/duplicate竞争/原status失败；不声称真实Keychain权限与设备锁屏已测 |
| cURL敏感数据/引号 | 原Header/Body保留凭证，URL双引号允许shell替换，单引号body未转义 | URL token、Authorization、嵌套password均默认脱敏；原文显式false；O'Reilly与$()字符只输出安全引用，不执行命令 |
| 局部Tag背景与前景 | 原selectedColor局部覆盖仍读取全局onPrimary，外部foregroundStyle无法覆盖内部样式 | 黄色背景/黑字公开API，selected trait；Swift类型检查及iOS截图；未用trait断言代替VoiceOver实测 |
| 示例环境与草稿 | 原CYAppState.shared示例不存在；字体环境在overlay内侧；离线消费者只有展示 | 修正索引/TagGroup值语义；环境挂在反馈外侧，目录局部色彩环境不受根主题偏好覆盖；原生草稿Cancel不改持久化、Save显式写入，iOS UI通过 |

修复前日志在`/tmp/cy-round3-repro-ui.log`和`/tmp/cy-round3-repro-sample.log`；它们记录有意失败，不算最终测试失败。最终回归不依赖固定sleep排列竞争顺序。媒体示例“模拟失败”仅文案演示，未当作真实Photos故障注入验收。

### 命令与运行结果

| 验收 | 结果与证据范围 |
|---|---|
| 开工基线 | `swift test --disable-sandbox --skip-update`：214测试、0失败；日志`/tmp/cy-round3-baseline.log` |
| 最终完整macOS | 同命令：226测试、0失败；日志`/tmp/cy-round3-tests-final.log`。12个新增行为测试覆盖上述取消/更新/输入边界；颜色断言补入原测试 |
| Package构建 | `swift build --disable-sandbox --skip-update`通过，包含ExampleApp；保留工具链/依赖cache提示 |
| Public-only消费者 | `python3 scripts/verify-consumers.py --cache-from .build --output /tmp/cy-round3-consumer-proof.json`：五Proof编译/运行/链接排除检查通过，7行为测试通过；新CoreOnly边界和Offline编辑源码也在实际消费图中 |
| ExampleApp iOS宿主 | Scheme完整test通过：40原生回归、6UI测试；追加12个本轮行为测试进入现有宿主。表单焦点提交/搜索失败恢复/自定义反馈/存储恢复与新Snackbar交互均运行 |
| 独立消费者iOS宿主 | Consumers完整test通过：4UI测试，包括新增Offline取消不写入/保存才变更；既有分页恢复、注入与路由、图片退出取消及短列表循环仍运行 |
| 文档 | `python3 scripts/verify-doc-examples.py`：10示例通过，新增Tag局部前景、字段依赖重建、保留原错的Bundle读取 |
| 组件登记 | `python3 scripts/verify-component-matrix.py`通过；是存在性检查，不替代人工评审或UI验收 |
| 严格lint | `/tmp/cy-work/swiftlint/swiftlint lint --strict --quiet --no-cache`，0违规；未禁规则，未增加应用依赖 |
| 补丁与保留成果 | `git diff --check`通过；index导出补丁cmp相同，根Package.swift本轮无变化；新增文件未自动stage |

完整iOS运行命令（两个宿主顺序执行，不争用同一设备）：

```bash
xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp \
  -destination 'platform=iOS Simulator,id=D7961504-06E5-4C70-B37D-EBB8BF39C204' \
  -derivedDataPath /tmp/cy-round3-host-derived -clonedSourcePackagesDirPath /tmp/cy-offline-packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO \
  -resultBundlePath /tmp/cy-round3-example-final.xcresult CODE_SIGNING_ALLOWED=NO test
xcodebuild -project ConsumerFixtures/Host/Consumers.xcodeproj -scheme Consumers \
  -destination 'platform=iOS Simulator,id=D7961504-06E5-4C70-B37D-EBB8BF39C204' \
  -derivedDataPath /tmp/cy-round3-consumer-derived -clonedSourcePackagesDirPath /tmp/cy-offline-packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO \
  -resultBundlePath /tmp/cy-round3-consumer.xcresult CODE_SIGNING_ALLOWED=NO test
```

命令的设备ID/缓存路径只属于本机执行，不进入工程依赖。测试bundle保存在/tmp，持续复现用仓库测试源码、Scheme和命令，不能假定其他机器有这些缓存。

### 界面检查与未验证范围

实际运行ExampleApp的长文案/accessibility2：局部黄色Tag黑字可读、能够换行；CYListRow仍单行截断，作为明确限制保留。Snackbar显示后继消息、多行与44pt关闭入口，点击可关闭。第一次截图发现dynamicTypeSize只影响List、未影响overlay，调整修饰符顺序后重新运行；局部深浅色环境也改为environment覆盖，避免与App根主题preference冲突。输入清除按钮最小44pt，垂直padding放在field内防止清除按钮出现时抬高整行；搜索默认至少44pt。纯样式未增加镜像单测，使用现有表单键盘流程和界面检查。

本轮不产生新的性能达标结论。消费者原有短循环继续运行，但没有把它当作长期泄漏或大图性能通过；不据此更新前两轮测量JSON。缓存注释的无依据比例已删除。

未验证：iOS18/macOS15实际运行；真机/VoiceOver朗读与焦点、最大动态字体、所有小屏/iPad分屏/横屏/键盘/深浅色组合；真实Photos/相机/系统OTP和视频来源；锁屏/系统Keychain权限；磁盘满或并发编辑冲突；真实后端/认证/生产Schema迁移；iOS大图解码、帧率、长时间内存和TestFlight。新关闭/选中label或trait仅是实现改进，不是这些场景已通过的证明。

最终Gallery局部色彩环境修正后，单独重跑`-only-testing:ExampleAppUITests/ExampleAppUITests/testSnackBarReplacementAndLocalTagWithLargeLongContent`，1/1通过；bundle为`/tmp/cy-round3-gallery.xcresult`，日志`/tmp/cy-round3-gallery-ios.log`。完整Scheme的40+6通过在此之前，最后只有目录色彩环境这一行行为调整；未把单测重跑称为全Suite重跑。

从最终xcresult导出并实际查看了两张1206×2622截图：[大字体长内容Snackbar](../ConsumerFixtures/Evidence/round3-snackbar.png)、[局部配色Tag](../ConsumerFixtures/Evidence/round3-tag.png)。大字体长消息完整换行并保留关闭入口；Tag黑字配黄底，长列表行截断仍可见。图像仅是iPhone17这一场景，不代表完整设备/暗色/对比度/辅助功能验收。目录的局部colorScheme用于预览内容，不改变整个App的系统状态栏主题。

输入触点最终布局后，额外重建并运行DesignSystemConsumerProof，含LegacyConsumer旧调用，结果PASS（`/tmp/cy-round3-design-consumer-final.log`）；没有重做无关性能测量。最后的源码注释校正只涉及不存在的AppStorageValue/静态ThemeManager示例及按钮触觉误述；严格lint与diff空白检查再次通过。
