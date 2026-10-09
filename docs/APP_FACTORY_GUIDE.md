# App Factory 指南

本文描述当前代码已经支持的创建方式，不把规划能力写成现有能力。模板采用“稳定基础模块 + 可选实现模块 + 宿主组合”的结构。

## 当前评价

当前版本已经是可用的 App Factory 原型：模块依赖单向，Network、Image、Persistence 可选，启动配置集中在宿主 `AppConfig` / `AppBootstrap`，账号、业务模型和固定 Tab 已从 Foundation 移出。它适合作为个人和中小团队的新项目底座，但不是覆盖 Backend、账号、云同步和远程配置的平台 SDK。

主要优势：

- 7 个 Library Product，宿主只选择需要的模块。
- `CYAppState` 只管理主题偏好和语言，不要求账号状态。
- Router 保留多 Tab 机制，Tab ID 与业务 Route 由宿主定义。
- Persistence 只提供容器和 Repository 协议，SwiftData 模型由宿主持有。
- Network 默认无鉴权，账号模型、凭证格式和登录状态由宿主持有。
- Swift 6 构建通过，当前 Package 测试为 147/147。

当前限制：

- `CYAppCore` 能力较多，新能力不应继续无条件加入 Core。
- `networkClient` 属于可选的 `NetworkProviding` 能力，不在基础 `DIContainerProtocol` 中；离线 Feature 只依赖基础协议。
- DesignSystem 是静态语义 Token，还不是完整的可注入 Theme 系统。
- ExampleApp 是可运行的真实接入范例，覆盖 请求/loading/error/retry/Router/Persistence/设置。

## 模块选择

| 模块 | 分类 | 使用条件 |
|---|---|---|
| `CYAppCore` | Base | 所有使用模板能力的 App |
| `CYFeedbackStyle` | Base UI | 使用统一反馈样式时 |
| `CYAppDesignSystem` | Base UI | 使用语义样式和基础组件时 |
| `CYAppUI` | Base UI | 使用 AppState、Router、反馈视图、Picker/Share 时 |
| `CYAppNetwork` | Optional | 需要 HTTP、上传或下载时 |
| `CYAppImage` | Optional | 需要 Kingfisher 缓存、预取等能力时 |
| `CYAppPersistence` | Optional | 需要 SwiftData 基础设施时 |

完全离线 App 可以不选择 `CYAppNetwork`。如果不需要 Router 或 DesignSystem，也可以进一步减少模块，不必机械采用推荐组合。

## 宿主目录

```text
MyApp/
├── App/
│   ├── MyApp.swift
│   ├── AppConfig.swift
│   ├── AppBootstrap.swift
│   ├── AppTab.swift
│   └── AppRoute.swift
├── Features/
├── Models/
├── Services/
└── Resources/
```

`AppConfig` 保存宿主配置值，`AppBootstrap` 是唯一组合入口。业务模型、Tab、Route、账号服务、品牌资源和 SwiftData Schema 留在宿主。

## ExampleApp 接入范例

`ExampleApp` 是一个“小但真实”的 App，可直接作为新项目的复制模板。目录结构：

```text
ExampleApp/Sources/
├── App/
│   ├── ExampleApp.swift       # @main + RootView + Router/Tab 装配
│   ├── AppConfig.swift        # 宿主配置值
│   ├── AppBootstrap.swift     # 唯一组合入口
│   ├── ExamplePersistence.swift
│   ├── AppTab.swift           # 宿主 Tab
│   └── AppRoute.swift         # 宿主 Route
├── Models/
│   ├── Article.swift          # 网络域模型（Codable/Sendable）
│   └── BookmarkItem.swift     # 持久化域模型（@Model）
├── Services/
│   └── ArticleService.swift   # 网络访问收敛于此
└── Features/
    ├── Home/                  # 请求 → loading/error/retry → 列表 → 路由
    ├── Bookmark/              # Repository 读写 SwiftData
    └── Settings/              # 主题 / 语言
```

它演示了完整闭环：

- **网络请求**：`ArticleService` 依赖 `CYNetworkClientProtocol`，由 `AppBootstrap` 在 DI 注册客户端。
- **loading / error / retry**：`HomeViewModel` 继承 `CYBaseViewModel`，用 `executeTask` 自动管理，`HomeView` 用 `CYBaseView` 渲染。
- **Persistence**：`BookmarkRepository` 实现 `CYRepositoryProtocol`，收藏写入 `BookmarkItem`。
- **Router**：`AppRoute.articleDetail` 通过 `CYAppRouter.navigate(to:)` 跳转。
- **全局状态**：`SettingsView` 改 `CYAppState.theme` / `setLanguage`。

新建项目时按相同目录复制，替换 Model、Service、Feature 即可。


## 离线 App

```swift
import CYAppCore
import CYFeedbackStyle

@MainActor
enum AppBootstrap {
    static func start() {
        CYCoreBootstrap.configure(CYAppConfig(environment: .production))
        CYFeedbackConfiguration.configure()
    }
}
```

离线 App 不添加 Network product，不设置 Base URL，Feature 只依赖基础 `DIContainerProtocol`，不声明 `NetworkProviding`，因此编译期就不接触 `networkClient`。

## 网络 App

复用现有配置器，不创建第二套网络抽象：

```swift
CYCoreBootstrap.configure(config.core)
CYNetworkConfiguration.configure(
    environment: config.core.environment,
    baseURL: config.network.baseURL,
    defaultHeaders: config.network.defaultHeaders,
    requestInterceptors: config.network.requestInterceptors,
    responseInterceptors: config.network.responseInterceptors
)
CYBusinessCodePolicy.configure { $0 = config.network.businessCodePolicy }
```

`CYAppConfiguration` 只是 deprecated alias，新代码使用 `CYNetworkConfiguration`。

### 网络与登录边界

端点用 `authentication` 声明策略：

- `.none`：绝不注入凭证，也不恢复。
- `.optional`：有凭证则注入，没有仍发送。
- `.required`：需要凭证；认证失败时可以恢复并重放一次。

Network 不判断 `isLoggedIn`，不持有 User、Access Token 或 Refresh Token。需要登录的 App 在宿主实现 AccountStore/AuthService，通过 `CYCredentialInterceptor` 提供完整 Authorization Header，通过 `CYCredentialRecovery` 提供可选恢复动作。无需登录的 App 不做任何配置。

## Theme 与资源

DesignSystem 提供默认语义颜色、字体、间距和组件。品牌色、Hero Image、插画、App Icon 和产品字体放在宿主 Resources。

目前不应内置 Cute、Fresh、Professional 等 Theme Pack。只有多个真实 App 出现稳定换肤需求后，才考虑把静态 API 升级成可注入的 Color/Typography/Spacing Tokens。

## Persistence、Tab 与业务模型

- `CYPersistenceController` 接收宿主模型；Schema、迁移和查询属于具体 App。
- Bookmark、Tag、User 不属于通用 Persistence。
- `CYTabID` 与 `CYAppRouter` 是通用机制；具体 AppTab、标题、图标和根页面属于宿主。
- Route、Endpoint、Analytics Event 和 Onboarding 内容属于宿主 Feature。

## 新 App 工作流

1. 创建 App target，只选择实际需要的 Products。
2. 创建 `AppConfig` 与 `AppBootstrap`，先让最小 RootView 启动。
3. 定义宿主 AppTab/AppRoute；单 Tab App 不模拟多 Tab。
4. 配置 Assets、App Icon、品牌本地化和隐私声明。
5. 按 Feature 开发业务 Model、ViewModel、View、Service 和测试。
6. 需要网络、图片或 SwiftData 时再添加 Optional Module。
7. 运行 Package 测试与 iOS target 构建，再完成真机、TestFlight 和 App Store 验证。

## 永久边界

适合进入模板：跨多个 App 高频复用、无产品语义、API 稳定、可以独立测试的能力。

适合留在宿主：账号、业务 Tab/Route、Endpoint、SwiftData 模型、Repository、产品设置、分析事件、Onboarding、品牌资源和商业规则。

新能力至少应在两个真实 App 中出现相同需求后再考虑沉淀，避免 Core 再次膨胀。

## 验收清单

- 离线 App 不导入 Network 仍可构建。
- 默认端点不携带凭证，三种鉴权策略有测试保护。
- Core 不含 User、登录状态、Bookmark/Tag 或固定业务 Tab。
- Theme 不包含具体产品视觉包，品牌资源不进入模板。
- `App.swift` 只负责启动、根状态和 RootView。
- 文档示例使用当前公开 API，不依赖 deprecated 名称。
- 完整测试与目标平台构建通过。
