# 模块、组件与扩展复用评审

最新专项结论见文末「第三轮：多 App 组件与扩展专项」。以下第二轮消费证据保留为历史；第三轮明确修正的限制以最新表为准。

交付复核：2026-10-19；构建测量：2026-10-18；最终运行复核：2026-10-19。范围是当前 Unreleased 工作树（包含上一轮未提交成果），不是已发布版本承诺。未新增应用第三方依赖，保留七个 Library。执行记录、次数和测量范围见 [ENGINEERING_VALIDATION](ENGINEERING_VALIDATION.md)；可运行入口见 [ConsumerFixtures](../ConsumerFixtures/README.md)。

## 结论与判据

五个独立消费者仅使用 public API，通过本地相对 Package 依赖接入。没有复制框架源码、`@testable import` 或 ExampleApp 内部依赖。Core/离线/网络可以独立选用；UI 可挂宿主自定义服务和独立 Router。实际阻力集中在分页状态强绑定与网络会话配置的第三方类型入口，已兼容修复；没有证据要求拆分新的 Library 或替换 Factory。

“可选”必须分三层：目标消费者未选择的 Network/Image/Persistence 不编译进其目标图，也不参与其最终链接；但根 Package 声明的 Alamofire、Kingfisher、Factory 仍参与 SwiftPM 包级解析。根包 `swift build`、聚合测试或完整 ExampleApp 会选择更多目标，不能拿其日志代替单消费者证据。检查依据是独立 Proof 可执行文件的实际 `Objects.LinkFileList` 与编译模块日志，不是 import 数量。检查脚本会拒绝意外链接/编译可选模块。

## 七个模块的消费边界

| 模块 / 公开职责入口 | 直接 → 传递依赖 | 最少启动配置 / 默认全局 | 替换、泄漏和业务边界 | 旧消费者影响 / 证据 |
|---|---|---|---|---|
| CYAppCore：错误、Endpoint/网络/图片协议、Base/Paginated VM、工具、DI、反馈/偏好管理器 | FactoryKit；不依赖其他六库 | 工具无需注册；使用 Facade 的网络 getter 前才需注册网络；默认反馈/偏好有 shared | 服务协议可注入；Factory 注册扩展公开 Factory 类型。缓存、Logger、权限、去重器仍具体类型，不宣称任意实现可替换；无业务 Schema/账号/Route | 本轮无 Core API 变化；CoreOnly Proof 无网络注册运行成功 |
| CYAppNetwork：CYNetworkClient、Config、请求策略/拦截器/凭证恢复 | Core + Alamofire + FactoryKit | 显式 init(baseURL:) 无须注册；使用兼容容器才 configure；旧 init 默认 AF 会话 | 消费方持有 CYNetworkClientProtocol；Endpoint/响应/账号均宿主定义。旧 session 参数仍公开 Alamofire.Session；新增 Foundation 配置入口无需 import Alamofire | 加法兼容；NetworkOnly 本地 URLProtocol 验证成功、HTTP500、底层停止取消 |
| CYAppImage：CYKingfisherImageLoader、CYAppImageConfig | Core + Kingfisher + FactoryKit | 直接 init 无须注册；configure 仅在选择全局 DI 时使用 | CYImageLoaderProtocol 可整体替换；高级 manager 参数公开 KingfisherManager，默认 .shared。Data 边界仍需视图解码，无业务模型 | 本轮未改 API；既有实际 Kingfisher 下载/取消/缓存测试保留；CustomComposition 不选此库也能加载图片 |
| CYFeedbackStyle：Toast/Loading/Error 样式及配置 | 无其他 Library / 第三方直接依赖 | 无须启动；可选 configure，视图默认读取 shared | 样式值可显式传给支持 style 的视图；配置是进程级视觉策略，不是业务反馈状态；只用 SwiftUI 原生类型 | 无本轮破坏变化；品牌/样式快照测试 |
| CYAppDesignSystem：Token、按钮/输入/布局、页面状态、分页展示 | Core + FeedbackStyle → FactoryKit | 默认可直接用；品牌启动前 configure；本地化默认取 Core 全局语言 | 大部分输入是值/Binding/Builder。错误组合使用 CYAppError；旧分页便利适配使用具体模板 VM。新基础分页无需继承，操作均由宿主提供 | 两个新增公开类型，旧初始化器保持；独立消费者只声明此 Product 即可构建 |
| CYAppUI：Router/AppState、反馈挂载、远程图片、媒体、引导和 View 扩展 | Core + FeedbackStyle + DesignSystem → FactoryKit | 只挂使用的环境对象/修饰符；默认反馈、图片、语言有 shared；媒体由宿主配权限说明 | 注入 Toast/Loading/Alert/ImageLoader；Router 可独立构造。路由值/页面/Sheet内容归宿主。Photos/UIKit 类型是 iOS 平台边界；CYKeyboardObserver 与 PhotoAssetLoader 为 shared 工具 | 无本轮破坏变化；两个组合实例的服务/Router 隔离，UI 验证调用与挂载同实例 |
| CYAppPersistence：CYPersistenceController、创建/迁移基础设施 | SwiftData；不依赖其他六库或第三方 | 宿主给 Model/Schema/配置/迁移计划；使用 throws create 捕获失败 | 支持 containerBuilder；不是 Repository、账号或 Model 生成框架。公开 SwiftData 是明确平台契约，无模板业务模型 | 无本轮 API 变化；宿主 Note 内存 CRUD、原始 NSError 身份保持；旧 fail-fast init 限制保留 |

模块表的依赖列列出 SPM target 图，系统框架另计。CoreOnly 不是 Foundation-only：本机 Debug Proof 的 `otool -L` 还显示 SwiftUI、AppKit、Combine、AVFoundation、Photos、CoreLocation 等系统链接，来自 Core 的平台工具/权限/状态能力。未选 CYAppUI 不等于不链接系统 UI 框架；没有消费者需求证明这需要立刻拆库，也未声称 Core 零系统依赖。

### DesignSystem → Core 的实际成本

实际使用 Core：`BaseView.swift` 的 CYAppError；`PaginatedListView.swift` 兼容适配的 CYPaginatedListViewModel；Buttons、InputComponents、LoadingIndicator、BaseView、PaginatedListView 的 `.cyLocalized`（加载、清除、取消、错误、重试和分页末尾文案）。其余组件即使存在 Core import，也不能由此推断运行依赖；纯展示输入与页面状态适配分开评估。

DesignSystemConsumer 的最终链接含 Core、DesignSystem、FeedbackStyle、FactoryKit 及消费者/Proof 本身，不含 Network/Image/Persistence/Alamofire/Kingfisher。实测编译与字节证据在 [构建记录](../ConsumerFixtures/Evidence/build-proof.json)。Debug Proof 包含脚手架、调试信息与入口代码；大小不是纯库增量，也不是 App 安装体积。既有依赖承担错误/本地化/兼容状态能力，目前没有实际消费者收益支撑再拆库。

### DI 与实例隔离

DIContainerProtocol 有 11 项基础 getter，适合兼容组合根，对单 Feature 偏宽；cacheManager/logger/permissionManager/requestDeduplicator 为具体实现。新消费者直接注入所需网络/图片/反馈协议，未被迫实现整个容器；因此保留 Facade，不机械为每个工具新增协议。未来只有真实替换这些具体服务受阻时才收窄对应边界。

CustomComposition 的两个 HostComposition 各持有自己的 Router、Toast、Loading、Alert、ImageLoader；单元验证只影响一个实例，UI 以同一实例挂载反馈并导航。业务没有隐式回退到 shared。品牌 CYDesignConfiguration、默认 CYFeedbackConfiguration 是进程级；第二品牌在创建视图前设置，不能同时给两个窗口配置不同全局品牌。CYAppState 可注入偏好管理器，但 `.cyLocalized` 仍从全局本地化管理器取模板文案，不能宣称窗口级语言完全隔离；窗口专属文案应由宿主显式提供。默认参数只是兼容便利，不代表默认单例间绝无共享存储。

## 独立消费者结果

| 场景 / Product | 最少配置及结果 | 接入阻力 / 修复 |
|---|---|---|
| CoreOnly / Core | 直接 public 工具；解码与字符串边界 Proof 成功，不注册网络。编译/链接仅 Core + FactoryKit（另有自身入口） | 无；未修改模板 |
| OfflinePersistence / Core + Persistence | 宿主 @Model Note；throws create 内存库，CRUD/save/查询、初始化失败保持原始错误；原生 List + @Query 页面 | 复用上轮抛错工厂，无新增框架改动；消费页无需 Router/Network/Image |
| NetworkOnly / Core + Network | 自定义 Endpoint/Status，持有 any CYNetworkClientProtocol；ephemeral URLSessionConfiguration + URLProtocol 本地桩 | 原 public 入口自定义会话需 Alamofire.Session；新增 sessionConfiguration 重载。成功、500、取消并验证 stopLoading，不依赖公网 |
| DesignSystemConsumer / 只声明 DesignSystem | PrimaryButton、CYTextField、CardView、新分页；宿主 @Observable ConsumerPages；初次失败、追加失败同页恢复、刷新保留、取消、旧响应隔离 | 旧接口不能接自己的状态，且重试直接走 VM；新增状态快照/基础展示，保留旧 VM 适配；LegacyConsumerPage 在外部编译旧调用 |
| CustomComposition / Core + UI + DesignSystem | 自定义三类反馈、确定性本地图片 Loader、Router；启动第二品牌。无须 Config/Factory 注册 | 上轮 public 注入已足够，无框架修改；宿主样例反馈实现仅作替换证明，不承诺生产队列/自动消失策略 |

七个行为测试与五个 Proof 可执行入口均成功。消费者 iOS 宿主复用上述模块；分页恢复、反馈实例/路由、图片离开取消和大字体操作由 UI 自动化覆盖。旧 ViewModel 搜索流程仍由 ExampleApp UI/回归验证。构建/运行与测试次数详见验证记录。

## 分页修复与兼容契约

消费者在修复前无法传入宿主状态；原刷新/追加接受回调，错误重试却直接调用 VM，无法统一请求所有权。这是 P2 高频接入阻力，而不是请求状态机本身的新 P1。

- 新 `CYPaginationState<Item>` 是 Sendable 值快照，提供 items/loading/loadingMore/hasMore/errorMessage/failure(refresh/append)，没有网络、页码、账号或容器。
- 新 `CYPaginatedListContent` 接快照以及 onRefresh/onLoadMore/onRetry，保留 Row/Empty/Loading/Error 自定义入口。仅负责 List 状态和交互任务；视图退出取消显式操作与行任务。宿主仍须防并发请求、提交页码、取消与旧响应隔离；不能把渲染层当状态管理框架。
- 原 `CYPaginatedListView` 原签名保留，转换 VM 快照并代理到同一个 renderer；重试继续适配 `viewModel.retry()`，其余操作回调不变。没有两份分页状态渲染逻辑。
- 组件拥有 List，适合页面、NavigationStack 或 Sheet；不能再嵌套另一个 List/ScrollView。预加载是行出现触发，需宿主 guard；失败有 error/failure 时暂停自动追加，显式重试同页。
- 标识符稳定/唯一由宿主保证。页码型 VM 仍按 pageSize 推导 hasMore；新快照允许宿主自行决定结束条件，未引入通用游标框架。

## 全部公开 UI 与支撑类型能力矩阵

覆盖 FeedbackStyle、DesignSystem、UI 的全部 **76 个顶层 public 类型**（含样式、状态和平台桥接支撑类型）；内部 PhotoGridPicker/PhotoPreviewView 不算公开组件。公开 View/Color/Font 等扩展按后表补齐。`scripts/verify-component-matrix.py` 检查源代码导出类型在本表和可搜索目录中的存在，新增类型未登记会阻断 CI；它不能自动证明矩阵内容正确或视觉合格。

标记：C = 当前 macOS/iOS 编译；T = 有对应行为单元回归；I = 模拟器关键交互；D = 目录可查最小分组用法/组合，**不是人工视觉通过**。平台“共”指声明的 iOS18+/macOS15+；“i”指 iOS 条件编译，最低运行系统均待测。未具备的错误/取消等状态为宿主职责或不适用，不通过加占位属性伪装完整。

所有行共同未验收：真机 VoiceOver 朗读/焦点/顺序、最大字号完整视觉、所有小屏/横屏/分屏/键盘组合、所有深浅色对比度、系统减弱动效人工检查。identifier 仅作自动化定位。I 仅覆盖所列操作，不能外推整套组件视觉或辅助功能。

| 公开类型 / 适用场景 | 状态输入 → 行为输出 | 内容 / 样式入口 | VM / 默认单例 | 组合边界 / 平台 | 已验证 | 额外未验证 / 设计限制 |
|---|---|---|---|---|---|---|
| PrimaryButton、SecondaryButton、CYScaledButtonStyle / 提交、次操作 | loading/disabled/按压 → action；失败/取消归宿主 | title；Token 字体/色/高度/前景、ButtonStyle | 无 VM；启动品牌 | List/ScrollView/底栏，共 | C/T/D；外部按钮接入 | 极长按钮文案和最大字号截断 |
| CYTextField、CYSearchBar、CYVerificationCodeInput / 表单、搜索、验证码 | Binding/校验错误/focus → submit/change/清除/取消 | 标题、placeholder、图标、error；Token/验证码框尺寸 | 无 VM；内置文案全局本地化 | 表单/搜索；验证码使用独立输入焦点，共 | C/T/I/D，输入与键盘提交 | 复杂输入法粘贴/OTP 自动填充、键盘全尺寸矩阵 |
| CYPaginatedListView / 兼容分页页面 | 模板 VM → refresh/loadMore 回调，retry 委托 VM | Row/Empty/Loading/Error、threshold；外部 List modifier | 具体 CYPaginatedListViewModel，默认文案全局 | 自带 List；禁止嵌套滚动，共 | C/T/I/D，旧搜索流程 | 游标/排序/跨页业务去重由宿主 |
| CYPaginationState、CYPaginatedListContent / 独立状态分页 | 值快照 → refresh/append/retry；正常/空/加载/失败/恢复 | Row/Empty/Loading/Error、threshold、Token | 无模板 VM；默认本地化全局 | 自带 List，NavigationStack/Sheet，共 | C/T/I/D，独立状态；取消/旧响应 T | Host 必须 guard 并发与结果代次；全部布局矩阵 |
| CYLoadMoreButton / 手动分页 | loading/hasMore → async action | 内置文案/Token，外层 modifier | 无 VM；全局文案 | 普通容器/列表底部，共 | C/D | 独立按钮 action Task 不保证页面退出取消；宿主按需管理；非无限滚动引擎 |
| ShimmerModifier、SkeletonRow、SkeletonCard、SkeletonList / 占位 | shimmer active、rowCount → 无业务行为 | placeholder/尺寸/Token，`.shimmer()` | 无 VM | ScrollView/List 子项，共 | C/D | 占位不拥有请求；减弱动效实际视觉待测 |
| CYPageNavigationChrome / 原生导航风格 | title/displayMode/translucent → leading/trailing 操作归宿主 | 两侧 Builder、background/tint | 无 VM | NavigationStack 导航条，i | C/D | 导航栏折叠/不同系统外观 |
| CYPageActionBar、CYSearchFilterBar / 页面操作、筛选 | title/query/filter flag → leading/trailing/search/filter | Builder 或回调；Token | 无 VM；搜索内置文案全局 | 普通容器，共 | C/D；搜索 I | 单行 toolbar 长文案、大字号压缩；图标朗读需宿主补标签 |
| CYSplitViewContainer / 三栏 | 三栏内容 → 原生导航 | 三个 Builder，系统样式 | 无 VM | 自带 NavigationSplitView，共 | C/D | 实际 iPad 分栏/折叠、macOS 窗口宽度 |
| CYPageContainer、CYEmptyStateView / 页面和空态 | 标题/文案/空态 action → 宿主回调 | content、action、图标；Token | 无 VM | Page 默认 ScrollView，可 usesScrollView:false；Empty 可嵌列表，共 | C/D；分页空/失败状态 T/I | 不能把 Page 当非滚动容器；空态所有长文案布局 |
| CYBottomActionBar、CYBottomSafeAreaInset、CYStickyBottomBar / 底栏 | 内容/edge/spacing → Builder 中操作 | leading/trailing/inset content、background/padding | 无 VM | 推荐原生 safeAreaInset，共 | C/D；表单底栏 I | 键盘与旋转、手势条/分屏安全区 |
| CYFlowLayout / 标签换行布局 | 子视图/spacing → 布局 | 任意子视图；间距 | 无 VM | 有限宽容器，共 | C/T/D | 超宽单项/大量标签/RTL 性能 |
| CYListRow、CYSectionHeader、CardView / 行、分组、卡片 | 标题/副标题/图标 → 宿主内容操作 | 行 leading/trailing、Card content；Token | 无 VM | List/ScrollView，共 | C/D；外部 Card C | 长行/附件挤压、辅助功能分组顺序 |
| CYBadge、CYTag、CYTagGroup / 标签选择 | title/selected/selectedIDs 值快照 → tap/宿主更新 | 标签内容/选择回调、Token 与颜色参数 | 无 VM | FlowLayout/普通容器，共 | C/T/D | 多选焦点与长词溢出 |
| CYLoadingIndicator、LoadingView / 局部加载 | message/style → 无请求行为 | CYLoadingStyle 或 Token | 无 VM；默认样式 | 任意容器，共 | C/T/D；loading I | 不负责超时/取消；重载样式全部组合 |
| CYBottomSheetModifier / 半屏容器 | Binding/Detents → 系统 dismiss | sheetContent、detents/indicator | 无 VM | 原生 sheet；宿主负责展示状态，共 | C/D | 多层 Sheet、键盘改变 detent |
| CYSnackBarManager、CYSnackBar、CYSnackBarModifier / 底部消息 | 可观察消息/时长/动作 → perform/dismiss | 文案/action；Token/内置布局 | 可独立 init，默认 shared | overlay，共 | C/D | 第三轮已修复替换/回调竞争、补关闭入口并取消两行截断；完整布局矩阵待测 |
| CYBaseView、CYDefaultErrorView / 页面加载与错误 | 值 loading/CYAppError → retry/dismiss | content/errorView Builder、反馈样式 | 无具体 VM；默认共享样式 | overlay，宿主避免与页面全局 loading 重复，共 | C/T/D | 原错误/加载可同时存在；宿主定义优先级 |
| CYAppDimens、CYDesignTokens、CYDesignConfiguration、CYAppColor、CYAppFont / 启动品牌 | 启动 Token → 计算读取样式 | 主色/对应前景、动态字体、间距/圆角/尺寸 | 进程级配置，非 VM | 共 | C/T/D，第二品牌消费者 | 运行时品牌刷新/窗口独立品牌不承诺 |
| CYToastPosition、CYToastIconColorStrategy、CYFeedbackShadow、CYToastStyle / Toast 样式 | 值/位置/颜色策略 → 原生样式 | 字体、图标、背景、shadow、transition 等 | 值类型；默认 shared config 消费 | 共 | C/T/D | 所有自定义组合/对比度 |
| CYLoadingIndicatorStyle、CYLoadingCardStyle、CYLoadingStyle、CYErrorStyle、CYFeedbackConfiguration / 反馈样式 | 配置 → Loading/Error 呈现 | 独立样式、configure/reset | 配置默认 shared；可构造配置，视图默认仍读共享 | 共 | C/T/D | 不保证窗口级配置；暗色/大字号完整组合 |
| CYAppState / 通用偏好 | 注入 theme/localization → 可观察 theme/language | 宿主环境/Locale/重建；不存业务账号 | 默认共享管理器，可注入 | 共 | C/T/D | 模板 `.cyLocalized` 非窗口级语言；同 defaults 可共享偏好 |
| CYAlertManagerModifier / Alert 挂载 | 可观察协议 → 系统按钮/确认/dismiss | 管理器 title/message/type/action | 注入管理器，默认 shared | 原生 alert，共 | C/T/I/D，自定义 Alert | 同时多个 Alert 来源、VoiceOver 焦点恢复 |
| CYToastView、CYLoadingOverlay / 反馈展示 | message/type/style → 展示；交互由挂载层 | 显式 style，反馈配置 | 纯视图无业务 VM；挂载默认 shared manager | overlay，共 | C/T/I/D，独立 Toast/Loading | loading 遮挡与布局全矩阵；非业务队列实现 |
| CYRemoteImageView / 可替换加载器 | URL/loader → loading/success/error/retry；离开/URL 变化取消 | contentMode/placeholder、accessibility；外部尺寸 | 协议注入，默认 Core loader | List/ScrollView/页面，共 | C/T/I/D，本地 GIF、取消、URL 替换 | iOS 大图解码/快速多图峰值未测；不承诺预取与降采样策略 |
| TypewriterModifier / 打字文本 | text/trigger/speed/scene/reduceMotion → 任务播放/取消 | 原 View/文字，speed | 内部状态，无 VM | 共 | C/T/D | 实际读屏连续朗读/焦点、长文本性能 |
| RectCorner / 圆角支撑 | 角集合 → 裁剪 | cornerRadius modifier | 无 VM | 共 | C/D | 特殊 shape 命中区域 |
| CYMediaPicker、CYCameraView、CYShareSheet / 平台桥接 | source/filter/selection/items → confirm/cancel/系统回调 | label、配置项；native sheet | 无模板 VM；权限/Photos 是系统服务 | i，Photos/PhotosUI 条件 | C/T/D，选择状态/资源所有权 T | 真机相机、拒绝/有限权限、真实视频、分享目标均待测 |
| CYMediaSelectionManager、CYMediaType、CYMediaPickerStyle、CYMediaSource、CYMediaFilter、CYMediaItem、CYAlbumInfo / 媒体支撑 | PHAsset/UIImage/视频URL、限制 → 选择/异步数据 | 宿主 maxSelection/filter/原图/预选 | Selection 可独立 init；非业务模型 | i + Photos | C/T/D | 大量真实资产、视频加载失败与资源生命周期现场验收 |
| CYMediaPickerController、CYPhotoAssetLoader / 网格容器、系统资产加载 | selection/filter/album → confirm/cancel/load/cancel | 参数/回调、宿主权限说明 | Controller 内部 selection；Loader.shared，不支持替换 Photos 后端 | i + Photos | C/T/D，Photos 取消回调处理；未桥接 Task 取消到请求句柄 | 真机 Photos/缩略图压力、实际受限相册 |
| CYKeyboardObserver / 系统键盘 | 系统通知 → 可观察 height/visible/duration | `.keyboardAwarePadding()`；原生安全区优先 | shared / private init | i | C/D；表单提交 I | 独立观察器不提供；多窗口/浮动键盘 |
| CYOnboardingPage、CYOnboardingView / 引导 | pages/currentPage/完成 Binding → 完成/跳过 | icon/title/description、Token | 无 VM；默认演示 pages 可替换 | Page 共；View i，page TabView | C/T/D | 最大字体分页、读屏顺序；默认文案应由宿主替换 |
| CYSheetItem、CYAppRouter / 路由支撑 | tabs/host Hashable route/Sheet View → paths/selection/sheetItem | 宿主 destination、sheet(item:)、Deep Link 校验 | 独立 init 可用，shared 仅默认入口 | NavigationStack/TabView/Sheet，共 | C/T/I/D，独立路径和路由挂载 | 恢复/多窗口/复杂 Deep Link 由宿主定义 |

### 不以类型导出的公共扩展

| 扩展组 / 入口 | 输入、输出与组合 | 配置/状态依赖 | 已验证与未验证 |
|---|---|---|---|
| `.feedbackOverlay/.toastView/.loadingOverlay/.alertManager` | 同实例协议 → overlay/原生 Alert | 默认共享管理器/反馈视觉；支持显式独立实例 | T/I；切换 Tab 的隔离通过；读屏焦点、全场景遮挡待测 |
| `.cyBottomSheet/.snackBar/.cyBottomSafeAreaInset/.cyPageNavigationChrome` | Binding/manager/Builder → native presentation/inset/chrome | 见对应类型矩阵 | C/D；全屏/分屏/键盘组合待测 |
| View+Extensions：条件显示、圆角/边框/cardStyle、readSize、hideKeyboard、shake/pulse、safe area 等 | 值/绑定/回调 → 布局/动效；取消与参数由具体入口定义 | Core hideKeyboard 的 UIKit 操作 MainActor；大部分无业务状态 | C/T/D；不是所有布局组合通过；条件隐藏需要宿主考虑辅助功能可见性 |
| `.typewriter/.keyboardAwarePadding/.shareSheet` | 文本/键盘/分享状态 → 原生行为 | 见对应类型矩阵 | C/T/D；真机与读屏待测 |
| Color/字体 Token/渐变/EdgeInsets 与导航风格扩展 | 原生值/参数 → 样式 | 系统类型、部分 iOS 条件；没有业务服务 | C/D；Token 配置不覆盖每个局部样式参数，颜色对比度待测 |
| 媒体数组辅助（identifiers/loadImages/loadData 等） | 选中项目 → 异步平台数据 | 系统 Photos 与项目资源所有权 | C/T；不保证任意超大视频内存用量 |

## 问题分类和后续触发条件

| 分类 | 证据与处置 |
|---|---|
| P2 已修复：分页状态接入/重试入口不一致 | 外部消费者原签名无法接自己的 Observable；新增快照 renderer + 保留适配，同一份 List 渲染，行为与 UI 回归 |
| P2 已修复：会话注入需要第三方类型 | 外部 NetworkOnly 需要本地 URLProtocol；新增 Foundation sessionConfiguration；不移除高级 Session 入口 |
| 验收缺口已补：目录可发现性/公网图片验收依赖 | 目录新增全 public 类型搜索及更多组合；ExampleApp 在 --ui-testing 注入确定性图片；外部宿主一直只用本地 Loader |
| 可接受限制 | DI 兼容 Facade 较宽、Core 链接 FactoryKit、包级仍解析全部依赖、页码 VM、启动全局品牌/反馈样式、Photos/键盘共享工具；不因存在单例或 AnyView 就重构 |
| 待验证，未认定为 P1 | 第二轮曾待验收的 Snackbar 替换任务在第三轮修复；系统媒体/无障碍/最低运行时/真机性能，不能以代码审阅替代运行结论 |
| 未来能力 | 独立窗口主题/本地化、可替换缓存工具、游标适配、平台图像协议：仅在真实 App 需求和测量证明收益后推进 |

可以开始下一个真实 App：五种接入路径已有编译/运行证据，没有已确认仍未解决的通用接入阻塞。发布前仍必须验收该 App 的后端/鉴权、真实 Schema 迁移、权限与媒体、最低系统、无障碍和真机性能；这些是宿主上线门槛，不应标成模板已经通过。

## 第三轮：多 App 组件与扩展专项（2026-10-19）

### 当前判断与取证口径

适合作为个人/小团队、多种中小 App 的**可选择复用底座**，不宜把所有便捷扩展和平台桥接都视为同等成熟的默认路径。按钮、卡片、受控输入、反馈注入、分页渲染和 Core 基础工具有实际收益；导航/滚动所有权、区域校验、进程级品牌/语言、媒体和存储错误边界必须在接入时选择。没有证据需要新增复杂公共组件或重构七库。新 App 的账号、业务数据契约、权限用途、编辑冲突和上线验收继续属于宿主。

已重新阅读要求的七份入口/规则文档及 CHANGELOG，检查目录与祖先，无适用 AGENTS.md（依赖 checkout 中的 AGENTS 不适用于本项目）。本轮输入已有前两轮 staged 成果；保留 index、现存文件与证据，不 reset/clean，不自动提交。先跑原 214 项基线，核实分页失败恢复/renderer、品牌单一存储、图片请求身份、反馈同实例、抛错持久化、typewriter 取消已存在，没有再次实现。

以下表按紧密职责分组，覆盖要求范围；“保留”不是全设备/VoiceOver 认证。所有未实际运行项以 ENGINEERING_VALIDATION 的第三轮记录为准。源码可从同名文件找到；已有 public 类型/平台/状态输入的逐项矩阵保留在上文，不用类型数量证明质量。

### 组件清单：用途、边界、分类与本轮结果

| 名称 / 场景与封装价值 | 状态、定制、组合与适配依据 | 问题或限制 / 分类结论 | 本轮处理 |
|---|---|---|---|
| PrimaryButton / 主提交；SecondaryButton / 次操作；CYScaledButtonStyle / 统一按压 | 主按钮 loading/disabled 阻止操作、保留朗读标题；最小高度随多行增高；样式消费 Token、减弱动态效果 | **保留**。固定 String label，不能塞图标/自定义 loading；复杂 label 用原生 Button+Style。次按钮自定义样式未专门表达禁用色；外部 `.disabled` 负责交互 | 保留已有实现，不再造另一种按钮家族 |
| CYTextField / 标题+字段+错误 | Binding、secure、submit、纠错和 iOS 键盘类型；可放 Form/List。宿主 FocusState 示例已有实跑 | **调整**。清除图标目标过小；标题未作为内层 field 显式可访问标签，错误未关联朗读；不支持多行/富文本 | 清除按钮最小 44pt。多行直接 TextField(axis:) / TextEditor；未声称所有可访问性已通过 |
| CYSearchBar / 页内搜索；CYSearchFilterBar / 搜索与筛选动作 | Binding+submit/cancel；过滤面板通过回调组合；不自带滚动/导航 | **调整+补示例**。清除和筛选图标缺朗读名；默认 Search 为英文；取消只清值/回调，不保证收键盘；取消/防抖/条件重置归宿主 | 补本地化清除/筛选标签和清除触点；保留 SearchExample 的 `.task(id:)`+reset，原生导航搜索优先 `.searchable` |
| CYVerificationCodeInput / 数字短码 | 一个隐藏 TextField+可视格子，长度至少1，iOS OTP contentType，绑定过滤 Unicode `isNumber` | **调整（待真实 OTP 验收）**。默认6×48+5×12=348pt，小屏表单内可能放不下；opacity(0) 字段读屏/焦点未实测；初始绑定未必规范化；不是 ASCII/服务端验证码校验 | 目录继续用显式小框示例；报告宽度和 Unicode 限制，不新增复杂焦点框架 |
| CardView / 实色语义卡片 | Builder；padding/radius/background/shadow 均可局部覆盖，无滚动/导航 | **保留**。相较原生统一品牌；和 material `.cardStyle` 外观不同 | 不合并不同材质默认值；见下方重复清单 |
| CYListRow / 设置或摘要行 | 无 action 是内容，可嵌 NavigationLink；leading/trailing 插槽、action 时为 Button | **保留有边界**。标题/副标题硬性单行，leading 32pt；多行可用原生 HStack；action 包裹交互 trailing 会形成嵌套按钮 | 明确 Toggle/Picker 行不传 action；长说明不复制此行，使用原生 LabeledContent/VStack |
| CYSectionHeader / 分组+辅助动作 | 文本与可选 actionTitle/action；不带滚动 | **保留+补示例**。已有自带边距，放 List Section header 时可能重复内边距；动态字体布局全矩阵未验收 | 原生 Section 足够时不套包装 |
| CYBadge / 数量/状态 | 纯 Text 胶囊，可配前背景；多行随 Text 布局 | **保留**。不自动做99+或业务状态映射 | 计数上限和状态业务语义留宿主 |
| CYTag / 选择 chip | Button、外部选中值/动作、局部前背景；无 VM | **调整**。之前局部 selectedColor 仍强制用全局 onPrimary，浅背景无法配黑字；选中只靠颜色/字体 | 新增默认兼容的 selectedTextColor；增加 `.isSelected` trait；目录黄色/黑字示例及截图验证 |
| CYTagGroup / 筛选组 | 传 data、selectedIDs **值**、产出 CYTag 的 builder；不拥有选中状态；内部用 FlowLayout | **补示例/有限保留**。不是 Binding API；offset 身份不适合重排含内部状态的子项；要求具体 CYTag 限制更复杂 chip | 修正索引误称 Binding；复杂内容原生 ForEach+CYFlowLayout，不扩大泛型包装 |
| CYFlowLayout / 少量标签换行 | Layout 处理未知宽度；无业务、任意子项 | **保留有边界**。子项按 unspecified 测量，超宽单项不缩进容器；显式无限 proposal/RTL 未验收；每次测量/放置重新算全部子项 | 不宣称大量数据的惰性布局；超长 chip 用受约束内容/原生网格，未作无测量性能重构 |
| CYPageContainer / 有标题的内容页 | 默认 ScrollView，`usesScrollView:false` 已可关闭；toolbar 插槽；**不**创建 NavigationStack | **保留+补示例**。showsNavigationBar 实际控制自绘 header，不隐藏系统导航；名字容易混淆 | 修正上轮“始终自带滚动”的描述；List/Form/分页用 false 或直接原生页面 |
| CYPageActionBar / 页内操作；CYPageNavigationChrome / 系统导航外观 | 前者 HStack/Builder、单行；后者 iOS toolbar modifier，不拥有导航 | **有限保留/调整待后续**。不是同一种容器；Chrome 的 isTranslucent 实为 toolbarBackground 的可见/隐藏开关，不能保证 UIKit 透明度 | 文档揭示实际行为；建议原生 toolbarBackground/toolbar/titleDisplayMode，未在本轮改旧参数语义 |
| CYSplitViewContainer / 三栏 | 已创建 NavigationSplitView，仅三内容 builder | **建议停止扩充**。不暴露 columnVisibility/preferredCompactColumn 等，原生写法更容易控制 iPad 折叠 | 保留旧入口；需要列状态直接用原生 NavigationSplitView，不复制包装源码 |
| CYBottomActionBar / 底部排版；CYStickyBottomBar / 同布局别名；CYBottomSafeAreaInset / 原生转发 | ActionBar 两侧 builder；Sticky 已委托 ActionBar；Inset 委托 safeAreaInset | ActionBar **保留**；其余 **合并/建议废弃**（仅推荐，不删 API）。Sticky 不拥有固定定位；Inset 包装无新增行为 | 不重复合并已共享的 renderer。推荐 `.safeAreaInset(edge:.bottom){CYBottomActionBar...}`，键盘优先系统安全区 |
| CYLoadingIndicator / 局部加载；CYLoadingOverlay / 全屏遮罩 | 已统一 Indicator，共享样式；文案 label、减弱动态效果；Overlay 不拥有任务 | **保留**。局部布局与全局遮罩职责不同；LoadingStyle 与品牌 Token 分层独立，需要宿主配置配色 | 保留共用实现；不用所有反馈都覆盖页面；动态切换 reduceMotion 的现有 onAppear 脉冲尚未全面实测 |
| CYEmptyStateView / 空内容提示 | 文案、图标、可选操作，不自带滚动 | **保留**。maxHeight infinity 需要父约束；无数据不等于失败 | 搜索/分页已有空/恢复示例；原生 ContentUnavailableView 足够时可直接用 |
| CYBaseView、CYDefaultErrorView / 页面状态 overlay | content/error 插槽；CYAppError；loading 和 error 可以并存；局部/全局加载不能重复挂 | **保留有边界**。content 仍在底层，错误不是自动互斥页面状态机；默认错误样式进程级、关闭标签仍有英文 | 宿主定义显示优先级；需要独立内容状态直接 switch，不新增第二套状态框架 |
| CYPaginatedListView、CYPaginationState、CYPaginatedListContent / 分页 | 旧 VM 适配同一 List renderer；新入口独立快照+三个回调；空/初错/追加错/刷新保留/取消测试已存在 | **保留**。拥有 List；稳定唯一 ID、请求并发和代次属于宿主；VM 默认页码+数量判断结束 | 核实前轮，无重复实现；外部消费者和旧 ExampleApp 继续验证 |
| CYLoadMoreButton / 手动追加 | 值 loading/hasMore+async action；没有状态框架 | **调整待后续**。内部未保存的 Task，不保证退出取消；状态未及时回写可重复点击 | 新代码优先宿主 `.task(id:)`/持有 Task；需真实手动分页再补生命周期改动，未把它宣称成完整分页引擎 |
| SkeletonRow/Card/List、ShimmerModifier、LoadingView / 占位与动效 | Skeleton 不拥有请求；LoadingView 实为固定骨架组合，不是 spinner；shimmer 尊重启动时 reduceMotion | **有限保留/调整待后续**。负计数未完全夹紧、widthRatio 未规范化；onAppear phase 未重置的重现视觉待测；200pt 扫光是局部常量 | 不再混称 LoadingView 为指示器；传非负计数、0...1 ratio。无真实皮肤不加更多骨架种类 |
| CYBottomSheetModifier / 统一 detents | Bool Binding+builder；系统 sheet负责生命周期，支持平台差异 | **有限保留/补示例**。不支持 selection/onDismiss 等全部原生参数 | 简单使用可保留；复杂 sheet 直接原生 API，不扩展第二套弹窗框架 |
| CYSnackBarManager/View/Modifier / 底部带动作反馈 | 可独立 manager；替换消息；duration；action；overlay，读屏/动作由 View语义承载 | **调整已实施**。旧 sleep 的 try? 吞取消，旧 timer 会关闭后继；action 先执行后 dismiss 会吞掉回调新消息；dismiss 参数未使用、两行裁剪长内容 | 取消检查、先关闭再回调、MainActor action；非法计时保留至显式关闭；真正关闭按钮与多行；确定性任务回归及 iOS UI/截图 |
| CYDesignTokens/Configuration、AppColor/Font/Dimens、Theme / 品牌 | 一个锁存储；旧颜色入口委托；字体动态、局部颜色覆盖和前景 token；尺寸验证已存在 | **保留**。配置启动级、非多窗口品牌；Theme 值类型未被配置 API采用，不再扩充；局部颜色仍由调用方配前景 | Color(hex:) 全串校验，非法前缀不再部分成功；不把局部44pt触点、骨架尺寸机械变Token |
| CYRemoteImageView + Core/Kingfisher loader / 图片 | Data协议注入；URL/id隔离、离开取消、错误/重试；外部定义尺寸与 clipped/可访问性 | **保留有边界**。自动重试不是错误终态前的独立 UI；默认 loader.prefetch 无操作、clearCache 清共享 URLCache；大图仍在主actor构造平台图片 | 前轮取消/原字节修复保留；未测量就不搬解码、建新图像协议；实例 loader 改变而 URL 不变不保证重新请求 |
| CYMediaPicker/Camera/Controller、MediaItem/Selection/Types/Album、PhotoAssetLoader / 选择与资源 | 系统/网格/相机不同路径；公开 iOS桥接；单项视频持有副本生命周期已有测试 | **限制性复用/调整待专项验收**。网格含自己 NavigationStack；原图 Toggle 状态未回传/未改变加载策略；相机确认会写相册；videos过滤不阻止相机产图片；maxSelection规范化不同；拒绝全屏页缺取消入口 | 明确推荐简单需求用系统 PhotosPicker/`.system(source:.album)`；默认 grid API保留，但不推荐不经真实媒体验收直接上线；本轮不新增媒体框架 |
| PhotoAssetLoader、内部 PhotoGrid/Preview / 加载和预览 | 系统取消/失败回调避免 continuation 不结束；缩略图 NSCache，Photos对象在MainActor | **调整待真相册回归**。未桥接 Task 取消到 PHImageRequestID；缩略图键只含宽度不含高度；全量 fetchAssets 数组和相册计数路径明确；视频预览只是全尺寸图片；预览关闭与完成同一 onDone | 代码路径为证据，未宣称已有底层Task取消或大相册性能合格。系统加载失败 nil 与取消不区分；限量数据/需求再改 |
| CYShareSheet + shareSheet / UIKit分享 | items/excluded 类型传原生controller，iOS，sheet挂载 | **保留+补示例**。update 不更新已打开内容，无完成回调；静态 Transferable 内容优先原生 ShareLink（跨平台） | 接入指南给 ShareLink 选择路径，不新增统一分享服务 |
| CYToastView/反馈Modifiers/AlertModifier + Core反馈管理器 / 反馈 | 注入观察同实例；Toast/Loading/Alert分别挂载；已有两组合隔离和 Alert队列 | **保留**。Toast 是短提示，Snackbar 有动作，两者有真实差异；自定义manager需Observable；遮罩不等同所有辅助技术焦点封锁 | 保留已有Indicator共享和Alert同renderer，不再合并不同反馈语义；全VoiceOver焦点未验收 |
| CYAppRouter/SheetItem、CYAppState / 路由与偏好 | 独立实例；每Tab路径；宿主绑定 Tab selection 和 sheet；State只主题/语言 | **保留+补示例**。init未校验selectedTab属于tabs；恢复/Deep Link/路由目标归宿主；默认管理器/模板文案有进程级共享 | 索引删除不存在的CYAppState.shared，改持有CYAppState()；业务模型/路由未移入模板 |
| CYOnboardingPage/View / 一次引导 | Binding完成、宿主pages，空页自动完成；iOS page TabView | **有限保留**。固定按钮高度/图标、最大字体无滚动兜底；页数动态改变/减弱动效未完整处理；默认内容演示用途 | 原生分页/自定义引导也足够；文案、完成存储、资格条件留宿主，不增Onboarding服务 |
| CYKeyboardObserver + keyboardAwarePadding / 特殊键盘布局 | 系统通知映射整屏frame.height；shared、iOS | **建议废弃默认路径**（保留API）。不是视图与键盘交集；与SwiftUI自动避让叠加可能重复padding，多窗口/浮动键盘无法准确 | 新表单使用FocusState+系统安全区/scrollDismissesKeyboard；仅在确实忽略键盘安全区且验证交集时考虑旧工具 |

### 扩展与高频工具清单

| 名称 / 紧密方法组与封装价值 | 语义与边界 | 错误、并发、环境依赖 | 分类 / 本轮结果 |
|---|---|---|---|
| String.isValidEmail/PhoneNumber/IDCard/URL、matches | 邮箱为ASCII简单形状；手机号/身份证中国大陆；URL正则非通用；matches是局部匹配，需完整匹配自行锚点 | 正则失败false；无网络/身份真实性；不能代替业务校验 | **调整文档**；不破坏已有返回值。新URL用URLComponents并明确scheme/host允许规则；国际电话规则留宿主 |
| String.isNotBlank/isNumeric/isAlphabetic/isAlphanumeric | 空串false；数字/字母按Unicode Character，不等于可解析十进制/ASCII；组合字符截断按grapheme | 无全局状态；stripped只修剪两端 | **保留有边界**；补Unicode数字注释，truncated前轮已修复并复测 |
| capitalizedFirst、camelCaseToSnakeCase、snakeCaseToCamelCase、truncated、strippedHTML | 缩写连续大写不完整分词；snake转camel会折叠下划线；truncated后缀不计入length；HTML正则不是解析器 | 无错误上下文，strippedHTML不解码实体、不消毒 | **有限保留/建议不扩充**；修正HTML注释，命名转换优先JSON编解码策略 |
| String.base64Encoded/Decoded、urlEncoded/Decoded、md5、asURL/asData/toInt/toDouble/copyToClipboard | Base64/UTF8失败nil；query值编码非整URL编码；坏percent回退原文；Double可产生nan；MD5非安全哈希 | URL(string:)允许相对URL；剪贴板是系统UI操作；转换多为系统别名 | 编码/摘要**保留有边界**；纯别名**建议废弃新用法**，未批量加deprecated；不统一改失败返回值 |
| String.localized/localized(with:)/systemLocalized/cyLocalized + LocalizationManager | 前两者默认宿主bundle、当前全局语言；system走系统；cy读Core资源；format参数与本地化占位需匹配 | 全局语言不等于View locale；CYAppState注入manager不替换全局扩展；文案规则构造时冻结 | **保留+补示例**；窗口独立语言显式传资源/locale；未创建另一套翻译缓存 |
| Date.toString、timeAgo/timeAgoShort | toString四维缓存含Locale/Calendar/TimeZone/format，64项上限；相对时间当前无locale/referenceDate参数 | toString锁内安全；timeAgo跟系统Locale和Date()，不跟App语言 | **保留有边界**；App日期用原生FormatStyle设置locale/timeZone，测试显式日期；不重复实现前轮缓存 |
| Date.timestamp/init、isToday/Yesterday/Tomorrow/Past/Future、isSameDay/Month、year…weekday/isWeekend/isWeekday | 时间戳秒/毫秒明确；属性均Calendar.current；weekday=1是否周日取决日历；isWeekday只是非周末，非工作日/节假日 | 用户日历/时区可变，不能用于固定后端日期协议；isSameMonth未比较era | **调整建议/保留兼容**；业务日历与假期留宿主，精确判断用显式Calendar |
| Date.start/endOfDay/Month、adding(days/months/years/hours/minutes)、days/hours/minutesBetween | endOfDay=23:59:59不含最后一秒小数；endOfMonth=末日零点；差值绝对值且截断 | 日期运算失败回退self，异常Date转Int可能失败；不是可靠半开区间查询边界 | **建议用原生替代**：Calendar.dateInterval(of:for:)和显式date(byAdding:)；不改旧边界以免查询语义变化 |
| URL.appendingQueryItems/removingQueryItems/build、domain/urlPathComponents/isHTTP/isFile/openInBrowser | 字典追加实际上同名覆盖、顺序无承诺，不能表达重复query；build可选但不是host合法性校验；isHTTP按scheme比较 | 解析失败回原URL；open无完成结果且MainActor；原生URLComponents可保留重复项 | query/build **保留+补使用边界**；纯属性别名不再扩充；scheme/host安全允许列表由宿主 |
| Collection.safe/isNotEmpty/length | safe对合法集合Index才有意义，不使其他集合/无效String.Index变安全；可能线性indices.contains；length只是count | ArraySlice索引不从0开始；无并发/生命周期保证 | safe **保留**，length **建议废弃**；不复制系统集合能力 |
| Array.unique(by:)/unique/divided/chunked/sample/removeFirstSafe/removeLastSafe | 去重保首序；非正chunk保兼容[self]；sample无放回且非正返回[]；removeFirst有移动成本 | chunk上限计算避免加法溢出；sample先全量shuffled，不能当大流reservoir算法 | **调整已修复**sample负数、chunk边界；有针对测试和CoreOnly消费；小集合工具，不声称流式性能 |
| Array.intersection/union/difference、Sequence.grouped/sorted/sortedDescending | intersection/difference保留self重复值和顺序，非数学Set；union去重；排序按keyPath | 全量结果分配为明确路径；不是并发数据结构 | **保留有边界**；要集合语义用Set；不因全量处理就认定真实性能缺陷 |
| Dictionary.isNotEmpty/value/merge/merged/hasKey/keysArray/valuesArray | 简单便利，value是动态cast；merge后者覆盖；顺序无保证 | 不是深合并，value失败nil | **建议收敛**：isNotEmpty与Collection重复实现，先保留兼容；keys/values原生足够，不再扩同义API |
| Dictionary.queryString/jsonData/prettyJSON + Data.prettyJSON/asDictionary | queryString把任意Value插值，不支持数组/重复项/签名排序；JSON仅JSONSerialization支持类型 | jsonData失败nil、prettyJSON错误字符串是调试哨兵，不是成功数据；有些根值不接受 | **限制性保留**；业务编码优先Encodable+throws / URLComponents，不用调试字符串持久化 |
| Optional.or/isNil/isNotNil/then/orThrow/isNilOrEmpty/countOrZero/isNilOrBlank/orZero | 与??、if let重合；or默认值是急求值；orThrow表达必需值；nil与空/零合并要业务允许 | 无共享状态；orZero不适合区分未填写与0 | orThrow/判空 **保留**；急求值别名**建议停止扩充**，新代码优先原生??/map |
| Double.formattedAsCurrency/Percentage/WithSeparator、Int.formattedWithSeparator | 系统NumberFormatter；默认人民币symbol不等于币种，decimals只控制最大位；未显式Locale | 跟随系统格式，App内语言不会自动影响；非有限fallback需谨慎 | **建议新用法用原生FormatStyle**，未改变旧货币默认值/金融业务规则 |
| Double.formattedAsBytes、Data.humanReadableSize | 字节显示确有价值；有限Double向零取整 | Double无法表示Int64时原文本，避免NaN/Infinity/越界trap；Data.count可安全转平台Int64 | **调整已修复**字节数转换，覆盖nan/inf/边界，明确fallback不是成功字节数 |
| Double.rounded/clamped/isBetween/degreesToRadians/radiansToDegrees；CGFloat同类 | pow极大/极小位数可能Inf/0；clamped不能当NaN验证；角度转换简单但常见 | 负/倒置range构造本身由Swift限制；round不是十进制金融精度 | **有限保留**；精确金额/数值有效性留宿主，未建立通用数值框架 |
| Int.isEven/Odd/Positive/Negative、clamped/timeString/times | timeString适合非负普通秒数，%d对很大Int可能截断；负秒展示未定义；times非正不执行 | 大times同步阻塞调用线程；不承诺任意Int时长正确 | **调整建议**timeString；新时长用Duration格式，其他薄别名不再扩充 |
| Data.base64String/hexString/asString/decoded；Encodable.prettyJSON/toDictionary；Decodable.decode/from | hex有益；decoded/decode抛原始JSON错误；from可选兼容；toDictionary只对象根 | 自定义decoder/encoder由调用方拥有，勿并发修改配置；prettyJSON不保证成功可机器读 | throws **保留**，调试/可选入口**有边界**；前轮decode已实现，不再新造Result层 |
| CYMultiDateDecoder、DateDecodingStrategy.cyMultiFormat | 猜测格式，MM/dd优先；数字按秒不是毫秒；无时区文本默认当前时区 | 锁保护共享formatter；POSIX locale但未显式固定Gregorian；猜测不是严格后端协议 | **限制性保留**；固定后端使用专用decoder，歧义日期、毫秒和业务日历归宿主 |
| Bundle.decode、CYBundleDecodingError | 文件名含后缀、默认日期yyyy-MM-dd；封装读bundle有价值 | 包装错误只含文件名、丢原始codingPath；日期Locale/Calendar未固定；同步读取 | **调整建议**：复杂配置直接bundle.url+Data(contentsOf:)+Data.decoded(as:decoder:)保留原错；本轮不破坏既有error enum |
| FileManager路径属性/tempDirectory/fileExists/fileSize/磁盘空间 | 快捷路径/可选元信息；默认user domain，路径不是创建保证；部分仅系统别名 | size失败nil，formatted失败Unknown；url方法按path，不验证file scheme | **保留有边界/别名建议收敛**；宿主选择自己的根目录，不把服务端路径直传 |
| FileManager.createDirectoryIfNeeded/clearDirectory/directorySize | 创建/清空有用，clear删指定目录直接子项（含递归删除其目录）；size遍历全树 | create已存在file时直接返回；清理可能部分成功后throw；size跳过错误返回部分/0，非精确审计数 | **调整建议**。只用于宿主拥有缓存/临时目录，重要文件用原生抛错API并检查isDirectory；未加泛化文件框架 |
| Task.sleep(seconds/milliseconds)、retry、withTimeout | sleep便利薄包装；retry times=总次数，backoff亚秒；timeout竞争子任务 | retry取消/超时参数前轮已修；sleep本身不验证非有限seconds；结构化timeout须等待不配合取消的操作 | retry/timeout **保留**，sleep新代码用原生Duration；明确协作取消，不承诺强杀 |
| CYDebouncer/CYThrottler | GCD回调，debounce最后一次、throttle leading+可选最后trailing；默认main queue | 锁+身份，闭包锁外；cancel/reset不能撤回已经开始/派发的action；非有限间隔未定义；@Sendable不自动推导MainActor | **保留有边界**。SwiftUI搜索优先.task(id:)，非UI事件流可用工具；未重写前轮锁实现 |
| CYValidationRule/FormField/FormValidator | 值规则按顺序返回首错；聚合有稳定firstError；required修剪但其他规则不自动修剪；regex是局部匹配 | 缺字段当空串；name/message构造时本地化；match捕获字符串快照，需依赖变动后重建；负长度逻辑非配置验证 | **保留+调整文档**。修正不存在fields:初始化；强调中国手机号/快照。表单业务规则/异步服务端校验不入模板 |
| CYCacheManager、CacheSerializer/JSON/PropertyList | actor串行内存+磁盘TTL；命名空间摘要；save/remove/clear返回Result；load是可丢弃缓存 | load的nil合并缺失/过期/损坏/I/O，日志留错；nil/空namespace清理全部；多实例同目录不构成事务隔离；ttl不验证NaN/Inf；不能用于唯一数据源 | **保留+校正文档**。移除无复现实验的“快2–3倍/缩50%/10KB阈值”，不做虚构优化；新命名空间需明确清理范围 |
| CYAppStorageHelper、CYAppStorage | Codable持久化快捷入口；wrapper可注defaults；helper仅standard且用自己key注册表clearAll | 两者JSON写失败静默；wrapper失败回默认、不是SwiftUI DynamicProperty，不自动更新View；helper清理不覆盖wrapper，注册表多步写非事务 | **建议新代码不用作关键写入**。简单偏好原生@AppStorage；可靠Codable用JSONEncoder/Decoder throws+注入defaults；保留兼容，不合并有不同清理契约的两入口 |
| CYKeychainHelper/Accessibility/Error | 服务+账号定位，save/delete Result、readResult区分不存在/系统错误 | 旧先删后加可能更新失败/丢旧值；readStringResult对坏UTF8仍success(nil)；单例无App Group/accessControl框架 | **调整已修复**更新优先，notFound才add，duplicate竞争再update一次；不含新值/可访问级别的定位查询；错误原status保留，日志不再输出账号。系统权限/真机锁屏未验收 |
| UIImage resized/fit/cropped/square/rotated/PNG/JPEG/HEIC/tint/blur；UI compressedData/scaledToMaxWidth | 裁剪rect按像素、fit可能放大；两个压缩/缩放组部分互补，PNG/JPEG多为别名 | 大图同步renderer/CIContext；尺寸/NaN/负maxKB未全面防护；压缩降质量不保证maxKB；withTintColor撞系统同名API | **建议收敛/限制性使用**。图像处理优先原生有明确尺寸/预算的宿主pipeline；仅已有小图用法保留，未无测量引入新处理框架 |
| URLRequest.cURL | 可复制诊断命令，但原先URL/Header/Body泄漏凭证且引号未转义 | 改为共享NetworkLogRedactor默认；shell单引号引用，不执行任何命令；raw须显式false；流Body不读取 | **调整已修复**。默认输出不是可凭原凭证重放的完整请求；测试覆盖URL/嵌套JSON/header和单引号/命令替换字符 |
| Result.value/error/isSuccess/isFailure/getOrDefault/success(Void) | 简便检查；可选value/默认值会吞failure上下文 | 不执行新异步任务，默认值急求值 | **有限保留/建议少用别名**；写入优先try result.get()/switch，不把默认值当成功 |
| View.if/isHidden/onFirstAppear/center/readSize/debugFrame/snapshot | 布局便捷；if/remove改变结构身份，首次仅当前View身份；size是布局回调非性能测量 | hidden保位不等于业务禁用；snapshot UIKit同步需有限尺寸；readSize写回尺寸可能循环 | **保留有边界**。优先原生动态modifier保状态，截图复杂视图优先ImageRenderer；不新增生命周期管理器 |
| View.cornerRadius(RectCorner)/border/cardStyle/ignoresSafeArea、Gradient组 | cardStyle是material卡片，CardView是语义实色；圆角名left实际映射leading，RTL可能有差异；gradientBackground委托linearGradient | 无业务状态；gradientBorder用原生内描边；safeArea转发纯别名 | 样式**保留**，转发别名**建议收敛**；保留材质差异，不为减文件合并 |
| shake/pulse/typewriter、Animation.cySnappy/Bouncy/Smooth/Gentle/Quick | 任务/scene/reduceMotion前轮已改；typewriter替换原内容为Text，字形修饰需确认；动画预设只是值 | Animation本身不能读Environment，使用者仍需reduceMotion分支；超长typewriter多次累加无测量不定性性能 | **保留**，不重复原生动画同名；不把identifier或可编译当作可访问性证明 |
| EdgeInsets(uniform/horizontal:vertical:)/top/bottom/leading/trailing/zero | 简化四边写法，无状态 | leading/trailing为方向语义，可接受负inset但宿主负责布局 | **保留**，无需另造间距类型 |
| View.navigationBarAppearance/navigationBarHidden/scrollEdgeAppearance、AppTheme.colorScheme | colorScheme正确值映射；hidden转toolbar；外观包装与Chrome部分重复 | titleColor非nil只切dark并未应用颜色，hideSeparator未消费；isTranslucent名称不等于实际效果 | 外观包装**建议废弃新用法**，保留兼容；新页面原生toolbar/toolbarBackground/toolbarColorScheme；不默默改参数以免外观变化 |

### 重复、封装层级与明确后续事项

- **已有内部合并，不重复做**：CYBaseView/CYLoadingOverlay共用CYLoadingIndicator；新旧分页共用renderer；旧颜色配置转统一Token；CYStickyBottomBar委托ActionBar；linearGradientBackground委托linearGradient；Alert两入口共用presentation。
- **不强行合并**：CardView是语义实色，cardStyle是material；Toast短提示，Snackbar带动作；PageActionBar自绘页内栏，NavigationChrome系统toolbar；Core UIImage编码和UI限KB压缩算法并不等价。应说明差异并优先原生，而不是按相似名字删除。
- **建议弃用新增调用**：Collection.length、重复Dictionary.isNotEmpty、Optional/Result急求值别名、CYBottomSafeAreaInset、Sticky别名、简单Split包装、三种navigation外观便捷封装、默认keyboardAwarePadding、UIImage同名tint/薄编码别名。没有批量删除、重命名或加deprecated，避免无收益迁移噪音。
- **明确未完成的调整**：OTP自适应和可访问输入；手动LoadMore任务；骨架非正计数/重播；导航参数语义；重要持久化错误；媒体原图/取消/缩略图键/拒绝退出。源码路径和触发在表中，不再将它们藏在“已支持”后面。媒体改动须系统资产fixture和权限验收；重要存储新代码已有原生替代，不为修所有历史工具扩成新框架。
- **性能证据**：目前仅前两轮的macOS图像适配微基准与iOS短列表循环。全量shuffled、数组枚举、主actor图片构造、全相册fetch是明确路径，不等于已测卡顿；本轮没有新增性能达标承诺。

### 常见场景覆盖与缺口选择

A=已有组合；B=原生足够；C=补Recipe；D=确有公共组件依据；E=宿主。

| 场景 | 选择与依据 | 可运行入口 / 本轮结果 |
|---|---|---|
| 内容列表、详情 | A，原生List/NavigationLink+Card/Row；长详情ScrollView，避免两层滚动 | Home/Bookmark；CYPageContainer可关滚动；已有消费者 |
| 搜索、筛选、分页 | A+C，SearchBar/Tag/Flow+分页；导航搜索B=.searchable；筛选业务E | SearchExample现有失败/空/恢复；目录补局部Tag前景；独立分页消费者保留 |
| 表单输入、提交 | A+B+C，Form、FocusState、CYTextField、PrimaryButton、规则值；TextEditor/Picker/DatePicker/Toggle原生足够 | FormExample含失败/重试/跨字段，目录已有原生控件；未加业务表单引擎 |
| 设置、偏好 | B，原生Form/Section/LabeledContent/@AppStorage；主题语言A=CYAppState | Settings已有实际入口；关键写入不用静默JSON wrapper；多窗口策略E |
| 图片、媒体、分享 | A+B+C；简单PhotosPicker/ShareLink原生最短，注入RemoteImage已有价值；网格仅明确需求选择 | MediaExample包含导入/释放；本轮文档补限制；真实权限/相机需验收，不再推荐网格为一律默认 |
| Loading、空、失败、反馈 | A，局部ProgressView/Indicator、Empty、Base/Pagination、Toast/Alert/Snackbar按语义选 | 本轮Snackbar复现、恢复/关闭和长内容UI；页面和全局反馈避免重复遮罩 |
| 页面、导航、底部操作 | A+B，原生NavigationStack/Split/toolbar/safeAreaInset+ActionBar；PageContainer只按需 | LayoutExample和消费者现有导航；不加新的页面壳 |
| 本地数据展示与编辑 | C+B，现有Note/SwiftData+原生List/Form/Sheet，缺的是草稿正确示例 | 本轮OfflinePage新增草稿编辑，取消不改模型，保存显式try/catch；消费者UI检查取消/保存；保存冲突E |

**真正值得补齐的通用组件**：本轮没有达到D的新增控件。最接近公共需求的是OTP在窄宽/动态字体下的输入适配，但它应先修现有控件，完成iOS18、OTP粘贴和VoiceOver验收，而非新造第二套。可取消的异步操作也优先用原生.task/宿主持有Task，不抽通用异步按钮框架。

**不建议继续扩充**：业务化登录/支付/订单/用户模型；把每个原生控件包一层；多套品牌/全局反馈配置；固定样式卡片和骨架皮肤；通用编辑Repository、万能表单、游标和账号框架。后续至少两个真实App证明相同需求，再考虑窗口独立语言/品牌、缓存替换协议、大规模标签布局/相册分页、图像降采样和精确数值工具。

### 给下一个 App 开发者的选择指南

1. 先用原生List/Form/NavigationStack/toolbar/safeAreaInset表达页面。要统一品牌时加CardView、按钮、CYTextField和ActionBar；一处只保留一个滚动/导航所有者。
2. 列表有自己状态用CYPaginatedListContent；需要默认页码VM才用CYPaginatedListView。稳定ID、筛选重置、取消和旧结果保护跟同一个状态所有者走。
3. 短提示Toast、需操作Snackbar、阻塞确认Alert；局部请求尽量局部loading。同一管理器既传业务又挂View；品牌在启动配置，局部背景配前景。
4. 文本规则是形状/本地区域策略；URL和日期协议用显式URLComponents/Calendar/Locale/TimeZone。失败需诊断选throws/Result，不用prettyJSON、from、默认值假装成功。
5. 简单偏好用@AppStorage；唯一数据用宿主SwiftData/文件保存；缓存允许丢，写Result要处理；凭证用Keychain显式service/account和readResult。普通图片可注入RemoteImage，媒体先从系统Picker/ShareLink起步。

第三轮改动文件、实际测试/构建/界面截图及未验证项见 [ENGINEERING_VALIDATION](ENGINEERING_VALIDATION.md#第三轮组件与扩展专项2026-10-19)。
