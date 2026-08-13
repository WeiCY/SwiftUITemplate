# CYSwiftTemplate

iOS SwiftUI 工程模板 —— 协议驱动、按需引入、Swift 6 并发安全。

提供网络请求、状态管理、路由导航、缓存、Keychain、权限、反馈 UI、设计系统与 SwiftData 持久化的完整骨架，业务代码依赖协议而非具体实现，所有模块均可通过 DI 替换，无需修改模板源码。

---

## 快速开始

### 安装

在 Xcode 中选择 **File -> Add Package Dependencies**，输入仓库地址：

```
https://github.com/your-org/CYSwiftTemplate
```

### 最小初始化

```swift
import SwiftUI
import CYAppCore
import CYAppNetwork
import CYFeedbackStyle
import CYAppUI

@main
struct MyApp: App {
    init() {
        CYAppConfiguration.configure(
            environment: .production,
            baseURL: "https://api.your-domain.com"
        )

        CYBusinessCodePolicy.configure {
            $0.successCodes = [0, 200]
            $0.tokenExpiredCodes = [401, 10001]
        }

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
- **Token 自动刷新**：Actor 隔离并发安全，HTTP 401 + 业务码双链路，自动重放
- **请求去重**：Actor 隔离，防止快速点击重复请求
- **协议驱动 DI**：基于 Factory，所有服务可替换，全套 Mock 实现
- **Swift 6 并发安全**：全量 `Sendable`、`@MainActor`、`actor` 隔离
- **SwiftUI 状态管理**：`@Observable` + `NavigationStack` + 多 Tab Router

---

## 验证状态

| 项目 | 结果 |
|---|---|
| SPM 构建 | ✅ 通过 |
| 单元测试 | ✅ 98/98 通过 |
| iOS Simulator CI | ✅ 已配置 |
| 平台 | iOS 18+, macOS 15+ |
| Swift | 6.0 (strict concurrency) |

---

## 文档

| 文档 | 说明 |
|---|---|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | 完整接入指南：网络、缓存、Keychain、主题、路由、特异化 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构设计：模块依赖、DI、状态管理、网络层、扩展方式 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 路线图：版本规划与后续开发计划 |
| [docs/REVIEW.md](docs/REVIEW.md) | 评测快照：代码审查与评分（2026-08-13） |
| [CHANGELOG.md](CHANGELOG.md) | 已发布版本变更记录 |
| [ExampleApp](ExampleApp/Sources/ExampleApp.swift) | 可运行 Demo（3 Tab 示例） |

---

## 联系与贡献

- GitHub: https://github.com/your-org/CYSwiftTemplate
- Issues: https://github.com/your-org/CYSwiftTemplate/issues
- Pull Requests: 欢迎提交改进建议
