# 架构与扩展边界

文档对应主干 Unreleased。接入步骤见 [GETTING_STARTED](GETTING_STARTED.md)，网络契约见 [NETWORK_GUIDE](NETWORK_GUIDE.md)。

## 模块与依赖

```text
CYAppCore -> FactoryKit
    ↑ CYAppNetwork -> Alamofire + FactoryKit       可选
    ↑ CYAppImage   -> Kingfisher + FactoryKit      可选
CYAppPersistence -> SwiftData                     可选、无其他模板依赖
CYFeedbackStyle                                  纯样式
CYAppDesignSystem -> Core + FeedbackStyle
CYAppUI -> Core + FeedbackStyle + DesignSystem
ExampleApp -> 按需组合以上 Products
```

7 个 Library product 保持不变。额外的 ExampleApp executable 和 CYTestSupport target 不属于 Library product；生产模块不依赖测试支持 target。

Core 定义网络、图片、反馈等稳定协议，提供 URLSession 图片默认实现。不反向依赖 Network / Image / Persistence。无网络 App 不访问 `networkClient`。

| 模块 | 内容 | 不承担 |
|---|---|---|
| Core | 协议、DI、缓存、日志、权限、Foundation 扩展、基础 ViewModel | 账号、业务模型、业务 Tab/Route、具体 HTTP 实现 |
| Network | URLRequest、响应策略、鉴权拦截、上传下载、去重接线 | 登录流程与凭证持久化 |
| Image | Kingfisher 桥接、取消、缓存和预取 | 业务图片模型 |
| Persistence | ModelContainer 创建与 Repository 协议 | 宿主 Schema、模型、迁移计划和业务 Repository |
| FeedbackStyle | Toast / Loading / Error 样式 | 管理器状态和业务逻辑 |
| DesignSystem | 语义 Token、通用布局与组件 | Feature 状态和业务规则 |
| UI | AppState、Router、反馈挂载、图片与媒体视图 | 业务路由和账号状态 |

只在多个真实 App 出现稳定重复需求后提取公共能力，不引入新的架构框架。表单、搜索和媒体组合场景保留在 ExampleApp。

## 组合根与 DI

```text
App.init -> AppBootstrap          框架配置、可选实现注册
App root -> ExamplePersistence    可恢复地打开宿主数据库
         -> AppDependencies      创建 Service / Repository / ViewModel / 反馈实例
         -> Feature              初始化接收所需依赖
```

`DIContainerProtocol` 只提供基础能力；`NetworkProviding` 独立提供网络。`CYFactoryContainer` 实现两者；`CYAppContainer` 保留为 Legacy / Compatibility Facade。新 Feature 优先接收所需协议，避免任意位置从全局容器查找依赖。

Factory 注册不会自动替换无参数反馈修饰符。组合根解析一次，把同一个管理器交给业务和视图。ExampleApp 的 Home / Bookmark / Settings 共用注入 Toast，根视图挂同一 Toast / Loading / Alert。

## 状态与并发

- `CYAppState`：MainActor + Observable，只保存主题、语言等通用偏好。
- `CYBaseViewModel`：MainActor + Observable，执行任务、错误与重试；按任务身份隔离收尾。
- `CYPaginatedListViewModel`：追加分页状态和请求代次。failure 区分 refresh 与 append(page)，成功后才提交页码。追加失败暂停自动重试，显式 retry 重试同一页。refresh 失败保留数据及元信息，reset 立即失效旧请求。
- 只需要 UIKit 的方法使用 MainActor：主题 apply/saveAndApply、设备 idiom、触觉反馈、键盘隐藏；偏好读写仍非隔离，不把整个 Core 隔离到主 actor。
- 缓存、去重与默认图片加载使用 actor；共享配置和回调桥接使用锁。锁内只转移状态，取消底层请求和恢复 continuation 在锁外完成。

分页当前采用从 1 开始的页码模型，按返回数量推导 hasMore。游标、服务端快照、跨页去重与总数属于宿主数据契约，未在本轮新增框架。

## 网络契约

请求链路：Endpoint → 构建请求 → 请求拦截器 → 发送/解码 → 必要时恢复凭证并重放一次 → 终态响应拦截器 → 结果。

`send` 提供 envelope、envelopeRaw、direct、empty、data 策略。requestVoid 走 envelope + CYEmptyResponse；requestData 是 raw Data，不参与凭证恢复/去重。仅 required 鉴权允许自动恢复；raw/direct/empty 收到 401 不自动恢复。

HTTP 204/205 空响应只为 CYEmptyResponse 直接成功；有 envelope 的响应仍按宿主业务成功码判定。拦截器终态执行一次，不因成功后的拦截器错误重放请求。

去重键对 method/path/query/body/headers/authentication 结构化编码后摘要，按结果类型和登记身份隔离；凭证切换时取消并替换去重器。

所有内置日志共享 `CYNetworkLogRedactor`：URL query、Header、嵌套 JSON 脱敏，无法解析的 Body 隐藏，错误描述不回退输出原文。具体规则及限制见网络指南。

## 反馈与观察

Core 管理状态，FeedbackStyle 保存视觉，UI 修饰符连接 SwiftUI。`feedbackOverlay` 包含 Toast / Loading，Alert 单独挂 `.alertManager(manager:)`。

协议使用 class + MainActor。自定义实现需要可观察的存储或转发可观察对象；协议本身不自动产生通知。Toast / Loading 读取存在类型属性，Alert 的存在类型入口与兼容泛型修饰符共用同一呈现实现。修饰符直接持有传入实例，重新注入时不会因 State 留住旧管理器。

## Router 与资源

每个宿主 CYTabID 独立 NavigationPath，TabView selection 双向连接同一个 Router。业务 Route 用 navigationDestination 注册。presentSheet 接收 View，宿主必须用 sheet(item:) 挂载 sheetItem。Deep Link 的 scheme / Associated Domains、参数校验和业务目标均由宿主拥有。

Core 与 ExampleApp 各有本地化资源。Package 内部读取 Bundle.module，Xcode 宿主读取 Bundle.main；ExampleLocalization 按 SWIFT_PACKAGE 条件选择。App 内语言和系统 Locale 是不同的输入；日期格式化需要显式传入 App Locale。

## 持久化与图片

Persistence 提供可抛错的 create(for:) 和 create(schema:migrationPlan:configurations:)。错误原样交给宿主，既不删除存储，也不伪装成内存持久化。兼容 init 保留 fail-fast 并标记废弃。currentSchemaVersion 不是迁移机制；真实版本、模型和 SchemaMigrationPlan 在宿主或测试中定义。

Kingfisher 桥接的 Mutex 状态机协调 continuation、取消句柄和终态；取消早于句柄登记或与完成竞争时只恢复一次。网络成功使用 result.data() 返回原始字节，缓存命中仍可能序列化，Data 协议也仍需视图解码。RemoteImage 以 URL 和请求身份隔离旧结果，取消不参与失败重试。

系统视频导入复制临时文件，由媒体项持有副本生命周期；外部 videoURL 构造不删除宿主原文件。

## 品牌与工具扩展

单一 CYDesignConfiguration 存储启动 Token；旧 CYAppColor.configure 委托到同一存储。CYAppFont / CYAppDimens 为读取配置的只读计算属性，保留现有调用方式。字体按 TextStyle / relativeTo 支持 Dynamic Type。运行时深浅色、语言可切换；品牌配置不保证运行时刷新，不增加第二套配置单例。

日期缓存覆盖 format / Locale / TimeZone / Calendar，锁内使用格式化器。MultiDateDecoder 串行保护格式猜测器。Task.retry 和 withTimeout 校验参数并尊重取消；超时是协作式的，不能终止不配合的子任务。

## 工程与测试

ExampleApp.xcodeproj 通过相对本地 Package 引用复用 Sources，无机器路径或签名身份。Scheme 包含原生回归和 UI 测试，CI 实际构建和运行宿主。

CYTestSupport 保存并恢复进入测试前的配置、日志级别与样式；Factory 修改使用 withScope，结合 manager.push/pop 和 TaskLocal singleton.clone 隔离两层缓存。全局配置测试在同一进程串行；Feature 用独立注入实例测试。模拟器测试、交叉编译与真机验证分别报告。

当前结果、测量范围和未验证项见 [ENGINEERING_VALIDATION](ENGINEERING_VALIDATION.md)。

## 外部消费者与展示层边界（第二轮）

ConsumerFixtures 是单独 Package，根依赖为 `..`；每个场景单独声明 Products。Proof 可执行入口用于检查真实编译/链接模块，聚合行为测试和 iOS 宿主复用同一消费者模块。按需选择可避免对应目标构建/链接，根包的第三方依赖仍会解析。证据与全部公开组件边界见 [MODULE_COMPONENT_REVIEW](MODULE_COMPONENT_REVIEW.md)。

分页分成宿主状态与展示：CYPaginationState 是值快照，CYPaginatedListContent 接收 refresh/append/retry 操作，只拥有 List 渲染及视图生命周期任务。旧 CYPaginatedListView 保留 ViewModel 接口，转换快照后使用相同 renderer；页码、请求并发、取消与结果代次仍归 VM/宿主。没有新状态管理框架或第二套渲染逻辑。

DIContainerProtocol 的 11 项 getter 是兼容组合根接口，具体缓存/Logger/权限/去重器并非任意实现可替换；新 Feature 只接所需服务。独立 Router 和反馈状态已验证，启动品牌/反馈样式和默认本地化仍是进程级策略，不能据独立实例宣称全局视觉/语言按窗口隔离。

CYNetworkClient 新增 Foundation URLSessionConfiguration 初始化重载，消费者无需 import Alamofire 即可注入本地 URLProtocol；高级 Session 入口与实现依赖保持。Image 的高级 KingfisherManager 入口也保留；常规界面通过 Core 图片协议即可替换加载器。

## 组件与扩展的复用取舍（第三轮）

公共组件以受控值/Binding/内容插槽为主，复杂页面使用原生容器组合。CYPageContainer有showsHeader和usesScrollView开关；分页拥有List；CYBottomActionBar仅处理排版，原生safeAreaInset处理定位。Tag支持局部selectedTextColor与全局onPrimary分工。Snackbar/Toast的动作与短提示语义保留，Snackbar旧计时取消不得关闭后继消息，MainActor动作先移除旧状态再调用。

没有新增业务框架或公共控件。原生SwiftData草稿编辑放在现有外部消费者；编辑模型、冲突和事务属于宿主。第四轮移除重复导航外观/全屏键盘高度补偿/静默存储属性；原生导航和键盘安全区是默认路径。Codable偏好使用注入UserDefaults的实例工具，load/save显式throws，不提供全局clear-all。

Keychain以service/account定位并更新，缺失后才add，重复插入时重试一次update；不删除旧条目再写。cURL默认复用日志脱敏，原文导出显式选择；共享字段规则不等于对未知字段/路径的保证。缓存序列化器按格式和实际模型选择，没有通用性能比例承诺。

## 第四轮控件与公开面

OTP由一个可见系统TextField拥有输入和无障碍语义，局部editing policy只处理ASCII规范化/完成边沿，不管理网络、账号或导航。宿主通过原生focused控制初始/完成焦点。普通字段是窄屏和大字体的默认表现，没有透明输入或固定格宽。

底栏保留ActionBar的布局和品牌价值，safeAreaInset/导航栏/分栏/键盘安全区交回原生。低价值更名扩展移除，安全下标、格式化、抛错解码、重试/超时取消及表单规则保留。网络通用凭证注入与恢复协调保持，登录/用户/订单等业务流程仍归宿主。
