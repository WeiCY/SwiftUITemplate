# CYSwiftTemplate

iOS 18+ / macOS 15+、Swift 6 的 SwiftUI 模板。保留 7 个 Library，网络、图片实现和 SwiftData 均可按需接入；业务模型、路由和 Schema 留在宿主。

## 批量创建独立 App

使用最小骨架生成独立 iOS App，统一组合根、目录、Debug/Release 配置和 CI：

```bash
python3 scripts/create-app.py --name MyApp --bundle-id com.example.myapp \
  --template-path "$PWD" --output ../MyApp
```

本地 path 用于开发验证；正式项目用 `--template-revision` 固定已发布的完整提交 SHA。
在 macOS 安装 XcodeGen 后，在新目录运行 `xcodegen generate --spec project.json`。
详见 [工厂化评审、使用与优先级](docs/APP_FACTORY.md)。生成宿主的 Xcode 编译和模拟器测试仍待 macOS 验证。

## 先运行示例

1. 用 Xcode 打开 `ExampleApp/ExampleApp.xcodeproj`。
2. 选择 `ExampleApp` Scheme 和任意 iOS Simulator，运行。默认使用 Mock，无需后端和开发者签名。
3. 首页验证列表、详情、收藏；设置页切换主题/语言；组件页查看按钮、输入、状态、反馈、图片、媒体、布局及表单/搜索组合示例。

```bash
xcodebuild -project ExampleApp/ExampleApp.xcodeproj -scheme ExampleApp \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/cy-example-derived CODE_SIGNING_ALLOWED=NO build
```

宿主复用 `ExampleApp/Sources`，通过相对路径引用本地 Package，没有复制框架或重复 `@main`。
组件页可切换深浅色、大字体和长文案；第二种品牌在 Scheme → Run → Arguments 添加 `--alternate-brand` 后运行。

## 新项目的最小接入

在 Xcode 添加 [Swift Package](https://github.com/WeiCY/SwiftUITemplate)，按功能选择 Product：纯工具仅 Core，离线存储 Core + Persistence，需要模板页面时选择 DesignSystem/UI。在宿主组合根完成配置，再通过初始化注入 Feature：

```swift
// compile-check: minimal-app
import SwiftUI
import CYAppCore
import CYAppUI

@main
struct MyApp: App {
    @State private var state = CYAppState()
    @State private var router = CYAppRouter()

    var body: some Scene {
        WindowGroup {
            Text("Hello")
                .environment(state)
                .environment(router)
                .preferredColorScheme(state.theme.colorScheme)
                .environment(\.locale, Locale(identifier: state.language))
                .id(state.language)
                .feedbackOverlay()
                .alertManager()
        }
    }
}
```

`feedbackOverlay` 包含 Toast 和 Loading；Alert 需另外挂载。使用自定义管理器时，业务和视图必须传入同一实例。
完整的 Bootstrap、服务、Repository、ViewModel 接线见 [接入指南](docs/GETTING_STARTED.md)。

| Library | 职责 |
|---|---|
| CYAppCore | 协议、DI、状态、工具、权限、默认 URLSession 图片加载 |
| CYFeedbackStyle | 反馈样式 |
| CYAppDesignSystem | 品牌 Token 与基础组件 |
| CYAppUI | AppState、Router、反馈视图、媒体和远程图片 |
| CYAppNetwork | 可选 Alamofire 实现 |
| CYAppImage | 可选 Kingfisher 实现 |
| CYAppPersistence | 可选 SwiftData 基础设施 |

## 验证与文档

```bash
swift build
swift test
swiftlint lint --strict --quiet
python3 scripts/verify-consumers.py --cache-from .build --output /tmp/consumer-proof.json
python3 scripts/verify-doc-examples.py
python3 scripts/verify-component-matrix.py
```

前两轮的独立消费者证据继续保留；第四轮执行破坏性公开API清理：原生导航/键盘安全区、单可见字段OTP及显式抛错Codable偏好，仓库内消费者和示例同步迁移。严格 lint 覆盖消费者和测试辅助代码。当前验证结果、环境限制和图片测量方法见 [工程验证记录](docs/ENGINEERING_VALIDATION.md)。App 编译、模拟器 UI 测试与真机验证分别记录，不能相互替代。

- [独立消费者与运行入口](ConsumerFixtures/README.md)
- [组件与扩展分类、使用边界、缺口和选择指南](docs/MODULE_COMPONENT_REVIEW.md)
- [模板规则](docs/TEMPLATE_RULES.md)
- [接入指南](docs/GETTING_STARTED.md)
- [架构与扩展边界](docs/ARCHITECTURE.md)
- [网络指南](docs/NETWORK_GUIDE.md)：统一 send、响应策略、可取消的凭证恢复和协议注入 Mock；日志正文默认关闭。
- [本轮网络验证范围](docs/NETWORK_VALIDATION_2026-10-23.md)：Linux 针对性验证与 Apple 平台待验证项。
- [实际使用规范、库与组件复核](docs/USAGE_REVIEW.md)
- [定位、网络监听、日志与隐私迁移](docs/PLATFORM_BOUNDARIES.md)
- [组件、媒体与缓存优化及迁移](docs/COMPONENT_LIFECYCLE.md)
- [当前复核结论](docs/REVIEW.md)
- [路线图](docs/ROADMAP.md)
- [变更与迁移](CHANGELOG.md)

文档对应主干 Unreleased；使用已发布 tag 时请阅读该 tag 的文档。

历史本地基线见工程记录；新增工厂流程的验证范围见工厂化评审，未宣称远端 CI 通过或新版本已发布。
