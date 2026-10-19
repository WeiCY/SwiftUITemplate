# 从零接入

适用于当前主干 Unreleased，iOS 18+ / macOS 15+、Swift 6。规则见 [TEMPLATE_RULES](TEMPLATE_RULES.md)，网络细节统一见 [NETWORK_GUIDE](NETWORK_GUIDE.md)。

## 1. 先启动宿主

打开 `ExampleApp/ExampleApp.xcodeproj`，选 `ExampleApp` 和模拟器运行。无需签名，默认 Mock。工程直接编译 `ExampleApp/Sources` 并引用上一级本地 Package。

```bash
xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/cy-example-derived CODE_SIGNING_ALLOWED=NO build

# 将设备名称替换为 xcrun simctl list devices available 的结果
xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/cy-example-derived CODE_SIGNING_ALLOWED=NO test
```

Scheme 包含 `ExampleAppUnitTests` 和 `ExampleAppUITests`。真机运行时需要宿主自行配置签名和 Bundle ID。

ExampleApp 的相机和自定义网格相册访问在 `HostInfo.plist` 配置用途说明。没有声明定位、麦克风或跟踪权限。系统 PhotosPicker 的选择授权与完整相册权限不同，不要为只用系统 Picker 的宿主强制申请整个相册。

## 2. 选择 Products

最小界面组合：`CYAppCore`、`CYFeedbackStyle`、`CYAppDesignSystem`、`CYAppUI`。有需要再添加 Network / Image / Persistence。

SPM 地址：[WeiCY/SwiftUITemplate](https://github.com/WeiCY/SwiftUITemplate)。离线 App 不调用 `networkClient`，也不导入 Network。

推荐宿主目录：

```text
App/          AppConfig、AppBootstrap、AppDependencies、AppTab、AppRoute
Features/     每个功能的 View / ViewModel
Models/       业务模型及 SwiftData Schema
Services/     网络与其他业务服务
Resources/    品牌、本地化及隐私资源
```

## 3. 装配与依赖注入

`AppBootstrap` 负责框架配置，`AppDependencies` 创建 Service / Repository / ViewModel。Feature 优先通过初始化获取所需协议，容器主要在组合根使用。保留 CYFactoryContainer / CYAppContainer 兼容入口，不要求整体迁移 DI 框架。

```swift
// AppBootstrap 中，按需配置
CYCoreBootstrap.configure(CYAppConfig(environment: .development))
CYFeedbackConfiguration.configure(toastStyle: .default, loadingStyle: .default)

// 有 HTTP 接口时才调用；同一进程只能配置一次
CYNetworkConfiguration.configure(baseURL: "https://api.example.com")

// 希望用 Kingfisher 缓存/预取时才注册
CYAppImageConfig.configure()
```

ExampleApp 在 `ExampleAppConfig.usesMockNetwork` 切换 Mock / 真实网络。默认 true；设为 false，并把 `network.baseURL`、端点和返回模型改为实际后端契约。Mock 中的样例 Article 由组合根注册。

`DIContainerProtocol` 只含基础能力。确实需要整体容器的网络功能可声明 `any DIContainerProtocol & NetworkProviding`，更小的 Feature 直接接收 `any CYNetworkClientProtocol` 或业务 Service 协议。

## 4. 反馈管理器必须和挂载实例一致

```swift
// compile-check: feedback-root
import SwiftUI
import CYAppCore
import CYAppUI

@MainActor
struct FeedbackExample: View {
    let toast: any CYToastManagerProtocol
    let loading: any CYLoadingManagerProtocol
    let alert: any CYAlertManagerProtocol

    var body: some View {
        Button("Save") { toast.show("Saved", type: .success) }
            .feedbackOverlay(toastManager: toast, loadingManager: loading)
            .alertManager(manager: alert)
    }
}
```

无参数 `.feedbackOverlay().alertManager()` 使用默认共享实例，不会读取 Factory 注册。注册自定义实现后，需要解析一次并把同一实例传给业务和挂载视图；不要在工厂每次解析时创建不同管理器。

协议是 `AnyObject`，自定义实现必须用 class。SwiftUI 的状态变化来自 Observation：实现应为 `@MainActor @Observable`，或转发可观察实例的属性。单纯遵循协议不会自动产生观察通知。Alert 支持 `any CYAlertManagerProtocol` 和兼容泛型修饰符；不再要求调用方解包存在类型。

完整可编译的转发实现见 `ExampleApp/Sources/App/AppDependencies.swift` 的 `ExampleToastManager` / `ExampleAlertManager`。使用 `--custom-feedback` 运行可验证自定义 Toast、MockLoading 和自定义 Alert。其界面驱动有模拟器 UI 测试保护。

## 5. 主题、语言与品牌

`CYAppState` 通过 Environment 注入，根视图挂 `.preferredColorScheme(state.theme.colorScheme)`。`CYThemeManaging.apply` 与 `CYThemeManager.saveAndApply` 是 `@MainActor`；后台调用请 `await manager.apply(theme)`。保存和读取偏好仍可在非主 actor 使用。

`CYDeviceHelper.isPad`、`vibrate`、`CYHapticFeedback` 需要 MainActor。不要为 UIKit 隔离问题把整个业务层变为 MainActor。

语言通过 `state.setLanguage("zh-Hans")` 更新；根视图用 `.id(state.language)`，系统控件再挂 `.environment(\.locale, Locale(identifier: state.language))`。模板文案来自 Core 的 Bundle.module；SPM ExampleApp 文案用自己的 Bundle.module，Xcode 宿主则用 Bundle.main，见 `ExampleLocalization.swift`。复制代码时不能把模板包资源当成宿主主 Bundle。

```swift
// compile-check: branding
import SwiftUI
import CYAppDesignSystem

func configureBrand() {
    var tokens = CYDesignTokens()
    tokens.primary = .teal
    tokens.onPrimary = .white
    tokens.accent = .orange
    tokens.fontDesign = .rounded
    tokens.spacingScale = 1.1
    tokens.cornerScale = 1.5
    tokens.buttonHeight = 52
    CYDesignConfiguration.configure(tokens)
}
```

在创建界面之前配置一次。当前不支持保证刷新通知的运行时换品牌；用户的深浅色、语言切换不受此限制。`CYAppColor.configure(primary:accent:)` 仍可用，与统一配置共享同一存储。主要按钮、输入框、卡片、标签、字体和间距读取 Token。

`CYAppFont.*` 是只读的计算属性，通过配置调整；不能赋值覆盖。自定义字体在宿主注册后设置 `fontName`，使用 relativeTo 保持 Dynamic Type；等宽数字字体保留系统等宽设计。更细的产品样式在宿主扩展，不再引入另一套主题引擎。

ExampleApp 默认品牌与 `--alternate-brand` 启动参数分别演示两种配置。

## 6. 分页、表单和搜索

子类重写 `fetchPage(page:pageSize:)`，页码从 1 开始：

```swift
// compile-check: pagination
import SwiftUI
import CYAppCore
import CYAppDesignSystem

struct DemoRow: Identifiable, Sendable { let id: Int }
@MainActor
final class DemoPages: CYPaginatedListViewModel<DemoRow> {
    override func fetchPage(page: Int, pageSize: Int) async throws -> [DemoRow] { [] }
}
struct PagingExample: View {
    @State private var model = DemoPages()
    var body: some View {
        CYPaginatedListView(viewModel: model,
                            onRefresh: { await model.refresh() },
                            onLoadMore: { await model.loadMore() }) { Text("\($0.id)") }
            .task { await model.load() }
    }
}
```

- 首次加载显示 loading，首次失败显示错误和重试，成功为空时保留可刷新的 List 和重新加载按钮。
- 有数据刷新时保留内容；刷新失败保留数据、页码和 hasMore，并显示失败重试。
- 追加失败记录 `.append(page:)`，行再次出现不会自动重试。`retry()` 重试同一页，成功后才提交页码。
- 取消不展示错误；请求代次阻止旧响应覆盖新状态。`reset()` 立即使旧请求失效并清空分页，适合搜索条件变化。
- 自定义 `emptyView` 的完整初始化还可传 `loadingView: () -> AnyView` 和 `errorView: (CYAppError, retry) -> AnyView`。
- 当前只支持页码分页，`hasMore` 通过返回数量与 pageSize 比较推导。不处理游标、服务端总数、动态数据快照或跨页去重；数据排序和稳定 ID 是宿主契约。

组件目录 → 搜索示例可切换首次/追加失败；关闭开关后点重试。输入 `empty` 返回空结果。搜索使用 `.task(id:)` 防抖和取消，条件变化先 `reset()`，保留过期响应隔离。

表单示例演示 FocusState、next/done、字段规则、确认密码跨字段校验、提交中、失败与重试。提交依赖可注入，不在公共 Core 引入业务表单框架。

## 7. SwiftData 初始化与迁移

```swift
// 宿主组合根中；BookmarkItem/BookmarkTag 由宿主声明
let persistence = try CYPersistenceController.create(
    for: [BookmarkItem.self, BookmarkTag.self]
)
RootView().modelContainer(persistence.container)
```

用 do/catch 捕获错误，并提供错误页和重试。`ExamplePersistence` 保留 controller、dependencies、error，失败后只重试打开；不删除数据库，不回退内存。`--fail-store-once --ui-testing` 仅用于示例内存故障演示。

旧 `CYPersistenceController(for:)` 仍保留 fail-fast 语义并已废弃；改为 `try .create(...)`。不存在 `.shared` 控制器。`currentSchemaVersion` 只是历史常量，已废弃，不构成迁移机制。

版本化宿主用 `Schema(versionedSchema: HostV2.self)`、自有 `SchemaMigrationPlan` 和 `ModelConfiguration` 调用 `create(schema:migrationPlan:configurations:)`。自定义 builder 的错误会原样抛出。

最小 V1→V2 可复制实现见 `Sources/CYAppPersistenceTests/MigrationTests.swift`：V2 添加可选 details 字段，轻量迁移后在实际磁盘存储中查询并验证 V1 title 保留。模型仍在宿主/测试中。修改真实生产模型前，使用旧版本真实数据库副本测试迁移；不要通过改版本数字代替迁移计划。

## 8. Router、Deep Link 与 Sheet

宿主定义 AppTab / AppRoute，创建一个 `CYAppRouter(tabs:selectedTab:)` 并注入。TabView 的 selection 读取 `router.selectedTab`，写入 `router.selectTab`；每个 Tab 用 `NavigationStack(path: router.binding(for: tab.id))` 和 `.navigationDestination(for: AppRoute.self)` 注册目标。

```swift
// compile-check: router-sheet
import SwiftUI
import CYAppUI

struct SheetRoot: View {
    @State private var router = CYAppRouter()
    var body: some View {
        Button("Open") { router.presentSheet(Text("Details")) }
            .sheet(item: $router.sheetItem) { $0.content }
    }
}
```

`presentSheet` 接收 View，由 Router 自动包装为 CYSheetItem。只调用它而未挂载 `.sheet` 不会显示。

Deep Link 在宿主 Info.plist 声明 URL scheme，然后 `.onOpenURL` 解析业务参数并导航。ExampleApp 支持 `cyexample://article/1`；该示例直接解析，复杂分发可注册 `CYDeepLinkHandler.shared.register(scheme:host:handler:)`，再在 `.onOpenURL` 调用 `handle(url:)`。Universal Links 还需宿主 Associated Domains 和服务端配置。

## 9. 图片和媒体

`CYRemoteImageView(url:imageLoader:)` 可注入加载器，默认使用 Core URLSession 实现；注册 Image 模块后可使用 Kingfisher。URL 更换会清空旧状态；旧请求不能覆盖新资源。取消映射为 CancellationError，不参与失败重试。

Kingfisher 8.11.0 桥接会取消实际 DownloadTask，并处理句柄晚于取消、同步完成和重复回调。网络成功使用 `RetrieveImageResult.data()` 返回原始字节；缓存命中可能序列化。Data 协议和视图解码仍保留重复处理限制，测量范围见 [验证记录](ENGINEERING_VALIDATION.md)。

媒体示例位于组件目录：相册授权、拒绝后的设置入口、网格取消、加载失败、图片预览、视频导入与释放。网格/相机的 `onCancel`、系统导入的 `onImportFailure` 有默认闭包，旧初始化可继续使用。系统 PhotosPicker 取消不会产生新媒体，也不会清空宿主已有内容；当前不提供系统取消回调保证。

系统视频通过 `CYMediaItem.videoURL` 获取文件；异步使用时保留 item，长期保存需复制到宿主目录。导入副本随最后一个媒体项释放而清理；`CYMediaItem(videoURL:)` 不删除调用方原文件。PHAsset 网格项不保证有 videoURL。

## 10. Codable、日期与并发工具

Codable 的模型定义和调用受类型检查，但 JSON 字段缺失/类型不匹配是运行时 `DecodingError`，不是编译错误。端点默认 convertFromSnakeCase，特殊 CodingKeys 必须与实际 decoder 策略一起验证。

`Decodable.decode(jsonString:)` / `decode(dictionary:)` 保留原始错误；旧 `from` 返回 nil 的语义不变。

`Date.toString(format:locale:timeZone:calendar:)` 默认使用系统设置；App 内语言需显式传 Locale。缓存键覆盖全部配置。`cyMultiFormat` 是格式猜测：歧义斜杠日期先 MM/dd，再 dd/MM，数字按秒时间戳解释；确定后端格式时优先使用明确策略。

`String.truncated(to:)` 在零/负数返回空字符串，不追加后缀。手机号和身份证号只做中国大陆格式检查；不是身份核验。

`Task.retry(times:)` 的 times 是总尝试次数，<=0 抛 exhausted；delay/backoff 必须非负且有限，取消立即停止。`withTimeout` 的 seconds 必须有限且 >0。超时通过协作式取消实现，会等待不配合取消的子任务退出，不能强行杀死任意操作。

typewriter 在文本/trigger/speed 更新、返回页面时重播；离开/后台取消。shake/pulse/typewriter 尊重减弱动态效果，不在消失视图中保留更新任务。

## 11. 测试与接入验收

运行 `swift build`、`swift test`、`swiftlint lint --strict --quiet` 和上面的 iOS 宿主命令。缓存受限时：

```bash
CLANG_MODULE_CACHE_PATH=/tmp/cy-modules SWIFTPM_MODULECACHE_OVERRIDE=/tmp/cy-modules \
  swift test --disable-sandbox
```

测试可复用 `Tests/Support/GlobalTestState.swift` 的快照恢复模式；Factory 修改用 CYGlobalTestState.withScope，结合 manager.push/pop 与 TaskLocal singleton.clone；单独 push/pop 不保存 singleton 缓存。全局可变配置测试在同一进程串行，普通 Feature 优先用独立实例测试。不要将恢复到默认值误当作恢复测试前状态。

编译、UI 测试、模拟器权限和真机测试分别记录。当前结果及剩余限制见 [ENGINEERING_VALIDATION](ENGINEERING_VALIDATION.md)。

## 12. 常用基础工具

缓存和 Keychain 的失败都应由宿主处理，避免忽略初始化和写入错误：

```swift
let result = await CYCacheManager.shared.save(value: "Example", forKey: "sample", namespace: "Articles")
if case .failure(let error) = result { /* 展示或记录安全的错误上下文 */ }
let value: String? = await CYCacheManager.shared.load(forKey: "sample", namespace: "Articles")

let save = CYKeychainHelper.standard.save("FAKE_VALUE", service: "com.example.app", account: "sample")
if case .failure(let error) = save { /* 宿主处理 */ }
```

缓存 namespace 与键使用摘要文件名，nil 与空 namespace 相同；当前 v2 缓存不会读取旧目录。Keychain 的访问级别按宿主后台/解锁需求配置。不要用普通缓存代替敏感凭证存储，也不要把凭证写入日志。

## 独立接入验证与本轮新增入口

开始新 App 时先按场景选 Product，直接注入 Feature 需要的协议。五个可运行的外部样例在 [ConsumerFixtures](../ConsumerFixtures/README.md)，不使用 ExampleApp 内部类型。CoreOnly 不需要注册网络；离线 SwiftData 使用宿主 Model 与原生 SwiftUI；高级第三方配置留在组合根。完整依赖与可接受限制见 [模块和组件评审](MODULE_COMPONENT_REVIEW.md)。

### 自己的状态管理接分页

不需要继承模板 ViewModel 的宿主使用 `CYPaginationState` + `CYPaginatedListContent`；三个操作属于同一个宿主。以下展示最小视图边界，状态更新、页码/取消/旧请求隔离的完整可运行实现见 `ConsumerFixtures/Sources/DesignSystemConsumer/DesignConsumer.swift`：

```swift
// compile-check: host-pagination
import SwiftUI
import CYAppDesignSystem

struct HostRow: Identifiable, Sendable { let id: Int }
struct HostList: View {
    let state: CYPaginationState<HostRow>
    let refresh: () async -> Void
    let append: () async -> Void
    let retry: () async -> Void
    var body: some View {
        CYPaginatedListContent(state: state, onRefresh: refresh, onLoadMore: append, onRetry: retry) {
            Text("Row \($0.id)")
        }
    }
}
```

renderer 拥有 List，直接放在页面/NavigationStack/Sheet，不放进另一个 List/ScrollView。宿主必须防止重复请求并隔离旧结果。失败快照同时提供 errorMessage 与 `failure`（refresh/append），取消时清除错误，失败后显式重试；刷新失败可保留 items。默认文案仍使用模板全局语言，需要窗口独立文案时传自定义 empty/loading/error 内容。

旧 `CYPaginatedListView(viewModel:onRefresh:onLoadMore:)` 无需迁移，仍使用 `viewModel.retry()`；两种入口共用同一个 renderer。继续使用模板 VM 时，刷新和追加回调应操作传入的同一 VM。外部 `LegacyConsumerPage` 和原搜索示例作为兼容编译/运行入口保留。

### 不 import Alamofire 的会话配置

```swift
// compile-check: foundation-network-session
import Foundation
import CYAppCore
import CYAppNetwork

func makeHostClient() -> any CYNetworkClientProtocol {
    let configuration = URLSessionConfiguration.ephemeral
    // 本地桩可通过 configuration.protocolClasses 注入；完整实现见 NetworkOnly
    return CYNetworkClient(baseURL: "https://example.invalid", sessionConfiguration: configuration)
}
```

原 `session: Alamofire.Session` 入口保持兼容，新参数没有默认值，因此原无 session 参数调用不产生歧义。网络实现仍基于 Alamofire；这个入口减少消费者代码对第三方类型的接触，不改变包级解析或链接成本。

## 组件与扩展的选择（第三轮复用专项）

先用原生 `List/Form/NavigationStack/NavigationSplitView/toolbar/safeAreaInset` 表达页面，再按需用模板统一样式。`CYPageContainer` 默认有 ScrollView，但已经支持 `usesScrollView: false`；其 `showsNavigationBar` 控制页内标题，不控制系统导航。分页 renderer 自带 List。`CYStickyBottomBar` 只是 ActionBar 的兼容包装，固定位置仍需宿主 safeAreaInset。多行设置项优先原生 VStack/LabeledContent，`CYListRow` 当前标题和副标题均为单行；带 Toggle 的 trailing 不要再传整行 action。

局部覆盖标签背景时，同时覆盖前景；`CYTagGroup.selectedIDs` 是值快照，点击后由宿主更新集合：

```swift
// compile-check: local-tag-colors
import SwiftUI
import CYAppDesignSystem

struct LocalTags: View {
    @State private var selected: Set<String> = []
    let tags = ["SwiftUI", "Offline"]
    var body: some View {
        CYTagGroup(tags, selectedIDs: selected) { value, isSelected in
            CYTag(title: value, isSelected: isSelected, selectedColor: .yellow, selectedTextColor: .black) {
                if isSelected { selected.remove(value) } else { selected.insert(value) }
            }
        }
    }
}
```

Snackbar 适合带动作的底部提示，与无动作短 Toast 分工。用 `@State private var snack = CYSnackBarManager()` 并挂 `.snackBar(manager: snack)`。`show` 替换旧消息；action 在 MainActor 运行，先关闭旧消息再执行回调，可以安全显示后继。duration 有限且为正时计时，非正/非有限/超计时范围时保留到关闭按钮或 `dismiss()`。不要用常驻 Snackbar 承载整篇说明。自定义 `.dynamicTypeSize/.environment/.preferredColorScheme` 要放在 overlay 修饰符之后，才能同时作用于内容和反馈。

验证码当前默认6×48+间距需348pt，窄屏要显式设置boxSize/spacing；它的 `isNumber` 过滤接收 Unicode 数字，不是服务端 ASCII 码规则。OTP 自动填充/粘贴和读屏需要宿主实际验收。键盘优先原生安全区、FocusState、scrollDismissesKeyboard；`keyboardAwarePadding` 是整屏键盘高度，可能与系统避让重复，不适合作为所有页面的默认修饰符。

简单媒体选择优先系统 `PhotosPicker` 或 `.system(source: .album)`，静态可分享内容优先跨平台 `ShareLink`。自定义网格有自己 NavigationStack，原图开关目前没有回传/改变导出策略，相机确认会写入相册，Photos 请求未桥接 Task 取消，视频在网格预览中不保证播放；这些都需要真实需求和真机验收。`CYMediaItem.loadData()` 可能把视频完整读入内存，上传大文件优先保留 item 并用 videoURL。示例的“模拟加载失败”只展示文案，不是Photos后端故障注入证明。

本地编辑无需公共编辑框架：[OfflinePage](../ConsumerFixtures/Sources/OfflinePersistence/OfflineConsumer.swift) 使用原生 List/Form/Sheet，把输入留在 draft 中；取消不改 SwiftData 模型，保存显式处理错误。复杂编辑冲突、唯一性和跨实体事务归宿主。设置偏好用原生 `@AppStorage`；`CYAppStorage` Codable 包装不是 SwiftUI DynamicProperty，编码失败仍静默且损坏值回默认，不推荐关键数据写入。

规则需要依赖另一个字段时，按当前值重新构造；默认错误文案也在规则创建时确定：

```swift
// compile-check: dependent-validation
import CYAppCore

func confirmationError(password: String, confirmation: String) -> String? {
    CYFormField(name: "Confirmation").required().match(password).validate(confirmation)
}
```

`phone()` 只检查中国大陆形状；邮箱不覆盖所有国际地址；`regex`/`matches` 是局部匹配，完整匹配需锚点。`String.isValidURL` 是旧域名式正则，不是通用 URL 或安全允许列表。URL/日期协议优先显式 URLComponents/Calendar/TimeZone/Locale；日期区间查询优先 `Calendar.dateInterval(of:for:)`，旧 endOfDay 不包含最后一秒的小数部分，endOfMonth 是末日零点。

需要保留 Bundle 解码原始 codingPath 并指定日期策略时，不用旧的固定日期 `Bundle.decode`：

```swift
// compile-check: explicit-bundle-decoding
import Foundation
import CYAppCore

func readConfiguration<T: Decodable>(_ file: String, bundle: Bundle, decoder: JSONDecoder) throws -> T {
    guard let url = bundle.url(forResource: file, withExtension: nil) else {
        throw CYBundleDecodingError.fileNotFound(file)
    }
    return try Data(contentsOf: url).decoded(as: T.self, decoder: decoder)
}
```

`CYCacheManager.save/remove/clear` 的 Result 要处理；load 的 nil 可表示缺失、过期或失败，缓存不能作为唯一数据源。nil/空 namespace 的 clear 清全部缓存；按需提供非空命名空间。PropertyList 支持嵌套 Codable，不承诺比 JSON 快固定比例；用实际模型往返和测量选择格式。

Keychain 保存按 service/account 更新，不存在时添加，竞争插入时再更新一次；失败返回原 OSStatus，不主动删旧条目。用 `readResult/readStringResult` 区分系统错误与缺失；坏UTF8当前仍会在字符串入口合并为nil，需要精确区分时读取Data自行解码。

`request.cURL` 现在默认复用日志脱敏并转义 shell 引号；它不是保留原始凭证的完整重放。仅本地确需原请求时显式 `request.cURL(redactingSensitiveData: false)`，不要把原文写日志。脱敏只认识既定字段名，URL路径和普通字段不能放秘密。Double字节数格式化遇NaN/Infinity/Int64越界返回原数值文本；负数sample返回空数组；`Color(hex:)`仅接受可选单个#、3/6/8位完整十六进制和两端空白。

完整保留/调整/补示例/建议废弃/宿主分类及未解决项见 [专项清单](MODULE_COMPONENT_REVIEW.md#第三轮多-app-组件与扩展专项2026-10-19)。
