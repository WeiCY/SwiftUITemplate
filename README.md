# CYSwiftTemplate

iOS SwiftUI 工程模板 —— 协议驱动、按需引入、Swift 6 并发安全。

面向个人开发和中小型团队的 SwiftUI 模板底座，目标是让新项目能快速接入、风格统一、长期迭代。开始使用前建议先阅读 [docs/TEMPLATE_RULES.md](docs/TEMPLATE_RULES.md) 了解规则，再查看 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) 完成接入。

---

## 快速开始

启动配置建议集中在宿主 App 的 `AppConfig` / `AppBootstrap` 中。`CYCoreBootstrap`
只负责 Core 配置；Network、Image 和 Feedback 仍由宿主按需调用已有配置入口，因此
完全离线的 App 不需要导入 `CYAppNetwork`。

先阅读 [模板开发规范](docs/TEMPLATE_RULES.md) 与 [完整接入指南](docs/GETTING_STARTED.md)，确认当前项目是否需要核心模块、UI 模块和可选模块，再执行接入。

### 安装

在 Xcode 中选择 **File -> Add Package Dependencies**，输入仓库地址：

```
https://github.com/your-org/CYSwiftTemplate
```

### 最小初始化

```swift
import SwiftUI
import CYAppCore
import CYFeedbackStyle
import CYAppUI

@main
struct MyApp: App {
    init() {
        CYCoreBootstrap.configure(CYAppConfig(environment: .production))

        CYFeedbackConfiguration.configure(
            toastStyle: CYToastStyle(position: .center),
            loadingStyle: .default
        )
    }

    @State private var appState = CYAppState()
    @State private var router = CYAppRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .preferredColorScheme(appState.theme.colorScheme)
                .id(appState.language)
                .feedbackOverlay()
        }
    }
}
```

完整组合示例见 `ExampleApp/Sources/App/AppConfig.swift` 和
`ExampleApp/Sources/App/AppBootstrap.swift`。旧的 `CYAppConfiguration` 网络命名空间仍保留
为兼容 API，新代码应使用 `CYNetworkConfiguration`。

> 完整接入说明（网络 / 缓存 / Keychain / 主题 / 特异化等）请阅读 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)。

---

## 核心模块概览

| 库名 | 用途 | 依赖 |
|---|---|---|
| `CYAppCore` | 协议、扩展、日志、DI、管理器、权限 | **必选** |
| `CYAppNetwork` | Alamofire 网络实现 | 可选 |
| `CYAppImage` | Kingfisher 图片加载 | 可选 |
| `CYFeedbackStyle` | Toast/Loading 样式定义 | 有 UI 时引入 |
| `CYAppDesignSystem` | 颜色、字体、间距、基础组件 | 有 UI 时引入 |
| `CYAppUI` | 路由、AppState、Toast/Loading 视图、引导页 | 有 UI 时引入 |
| `CYAppPersistence` | SwiftData 持久化 | 可选 |

### 使用规则

- 先看规则，再看接入文档
- 先接入必选和推荐模块，再按需加入可选模块
- 如果只是个人项目的最小闭环，优先保证 `CYAppCore`、`CYFeedbackStyle`、`CYAppUI`、`CYAppDesignSystem` 可用
- 如果项目需要网络、图片或本地存储，再引入相应实现模块

### 分层架构

```
Layer 0  CYAppCore (协议 + 工具 + DI)  ← 仅依赖 FactoryKit
         CYAppNetwork (+Alamofire)     ← 可选实现
         CYAppImage (+Kingfisher)      ← 可选实现
         CYFeedbackStyle (纯样式)
         CYAppPersistence (独立 SwiftData)
Layer 1  CYAppDesignSystem (颜色/字体/组件)
Layer 2  CYAppUI (AppState/Router/反馈视图)
         ExampleApp (Demo)
```

> 架构设计详情请阅读 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

---

## 核心特性

- **类型安全网络**：`CYEndpoint` 协议 + `Codable` 替代 MJExtension，编译时检查
- **业务码可配置**：`CYBusinessCodePolicy` 避免全局硬编码 `code == 0`
- **可选凭证机制**：公开/可选/强制鉴权按端点声明，宿主决定凭证格式与恢复逻辑
- **请求去重**：Actor 隔离，防止快速点击重复请求
- **协议驱动 DI**：基于 Factory，所有服务可替换，全套 Mock 实现
- **Swift 6 并发安全**：全量 `Sendable`、`@MainActor`、`actor` 隔离
- **SwiftUI 状态管理**：`@Observable` + `NavigationStack` + 多 Tab Router

---

## 验证状态

| 项目 | 结果 |
|---|---|
| SPM 构建 | ✅ 通过（macOS 宿主；本机沙箱环境需 `--disable-sandbox`） |
| 单元测试 | ✅ 147/147 通过（2026-09-16 本机验证） |
| iOS Simulator 构建 | ✅ 通过（`swift build` 交叉编译验证全部目标，无需 `.xcodeproj`；CI 步骤已同步修复） |
| 平台 | iOS 18+, macOS 15+ |
| Swift | 6.0 (strict concurrency) |

---

## 文档

| 文档 | 说明 |
|---|---|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | 完整接入指南：网络、缓存、Keychain、主题、路由、特异化 |
| [docs/NETWORK_GUIDE.md](docs/NETWORK_GUIDE.md) | 网络框架使用指南：请求、上传下载、可选凭证、业务码、去重与 Mock |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构设计：模块依赖、DI、状态管理、网络层、扩展方式 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 路线图：版本规划与后续开发计划 |
| [docs/TEMPLATE_RULES.md](docs/TEMPLATE_RULES.md) | 模板开发规范：适用场景、分层、接入、文档与测试规则 |
| [docs/APP_FACTORY_GUIDE.md](docs/APP_FACTORY_GUIDE.md) | 新 App 模块选择、Bootstrap、离线/网络组合与边界 |
| [docs/REVIEW.md](docs/REVIEW.md) | 评测快照：代码审查与评分（2026-08-13） |
| [CHANGELOG.md](CHANGELOG.md) | 已发布版本变更记录 |
| [ExampleApp](ExampleApp/Sources/App/ExampleApp.swift) | 可运行接入范例（网络/状态/路由/持久化/设置） |

---

## 联系与贡献

- GitHub: https://github.com/your-org/CYSwiftTemplate
- Issues: https://github.com/your-org/CYSwiftTemplate/issues
- Pull Requests: 欢迎提交改进建议
