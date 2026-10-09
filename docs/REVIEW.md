# 工程化评测

> 评测日期：2026-09-16
>
> 范围：模块、启动配置、Core/UI/Network/Image/Persistence、ExampleApp、测试与文档。
> 验证：Swift 6 Package 构建通过，测试全部通过（数量见 CHANGELOG 最新版本）。

## 结论

工程已经从“功能集合型 SwiftUI 模板”进入“可组合 App Factory 原型”阶段，适合作为个人和中小团队多个独立 App 的基础底座。当前不宜称为完整生产平台或自动生成器，因为 Theme 注入、发布流水线、iOS 运行级验证和多 App 版本治理仍需真实项目推动。

综合评分：**8.6 / 10**。

| 维度 | 评分 | 评价 |
|---|---:|---|
| 模块化与边界 | 9.0 | 7 个 Library；Network、Image、Persistence 可选，业务模型已移出 Foundation。 |
| 启动与配置 | 8.5 | Core Config 与宿主 Bootstrap 分工清楚，并复用现有 Configuration。 |
| 业务解耦 | 9.0 | Core 不再拥有 User/Auth、Bookmark/Tag 或固定业务 Tab。 |
| 网络设计 | 8.8 | 默认无鉴权，端点策略清楚，凭证恢复 single-flight，账号语义归宿主。 |
| UI 与 Theme | 7.8 | 默认 DesignSystem 实用，但仍以静态 Token 为主。 |
| 可测试性 | 8.7 | 覆盖关键边界；仍缺 iOS 运行级测试。 |
| 文档与示例 | 8.2 | 主指南已校准；ExampleApp 已重构为真实接入范例。 |
| 长期维护 | 8.3 | 方向合理，但 Core 体积、单例和多 App 版本同步需持续控制。 |

## 已达到的能力

1. 离线 App 可以不选择 `CYAppNetwork`；Image 与 Persistence 同样按需。
2. `CYAppConfig` 只描述 Core，宿主 `AppBootstrap` 组合各模块。
3. 账号、Bookmark/Tag、具体 Tab 与 Route 不再污染 Foundation。
4. 网络端点默认 `.none`，无需账号的 App 没有认证成本。
5. Router 管理任意 `CYTabID`，Persistence 接收宿主 Schema。
6. 模块名、目录、Composition Root 与测试边界对 Codex 较友好。

## 主要问题

### P0

- ✅ 已修复：`networkClient` 从基础 `DIContainerProtocol` 拆到可选的 `NetworkProviding`。离线 Feature 只依赖基础协议，网络 Feature 通过 `DIContainerProtocol & NetworkProviding` 获得编译期保证。
- 新 App 必须从 xcconfig/Info.plist 注入 Base URL，不能沿用 Example 占位值或提交密钥。
- Package 测试不能替代 iOS App target、真机权限、StoreKit 和生命周期验证。

### P1

- DesignSystem 是静态语义 Token，尚不能自然安装外部 Theme Pack。应等待多个 App 验证共同 Token 后再升级。
- Core 已包含较多 Helper/Manager；新增能力必须证明跨 App 高频复用。
- 全局配置器和 Manager 使用单例，需要继续关注测试隔离。
- Analytics 是轻量抽象；Crash 和生产可观测性由宿主选择。

### P2

- 尚无 5/10/20 个 App 的版本治理、迁移日志和批量升级机制。
- 缺少正式 iOS UI/集成测试矩阵、性能基准、依赖安全与隐私清单审计记录。
- ✅ 已改善：ExampleApp 已重构为 `App / Models / Services / Features`，覆盖网络、loading/error/retry、路由、SwiftData 与设置。仍缺权限、SwiftData 迁移和发布配置示例。

## 第三方依赖

| 依赖 | 评价 |
|---|---|
| FactoryKit | 已深入 DI，当前移除收益低；应控制其使用边界。 |
| Alamofire | 隔离在 Optional Network，离线 App 可不链接。 |
| Kingfisher | 隔离在 Optional Image，Core 保留轻量 URLSession 图片加载。 |

当前没有必要为了“纯原生”立即替换依赖。更重要的是不让 Alamofire/Kingfisher 类型泄漏到 Feature 契约。

## 规模化建议

### 1 至 5 个 App

- 保持复制模板 + 宿主配置。
- 记录每个 App 使用的模板版本、Optional Module 和自定义扩展。
- 只有重复实现才回收到模板。

### 5 至 10 个 App

- 建立模板版本、迁移指南、发布检查清单和 CI 矩阵。
- 根据真实品牌差异评估可注入 Theme Tokens，不预置主题包。
- 统一 AppConfig 命名、日志和 Analytics 基础规范。

### 10 至 20 个 App

- 考虑稳定分支、迁移脚本或内部生成工具。
- 建立兼容与弃用周期，避免复制后永久分叉。
- 建立构建、测试、隐私、依赖和发布自动化，不把这些逻辑塞进 Core。

## 下一步

1. 用一个离线 App 和一个网络 App 走完创建到 TestFlight。
2. 补 iOS target 构建和关键运行级测试。
3. 持续保持文档与公开 API 一致。
4. 等多个 App 出现真实重复需求后，再决定 Theme Token、设置组件或发布工具是否进入模板。

当前最重要的不是继续拆模块，而是验证这些边界能否减少新 App 的基础设施工作，并保持后续升级可迁移。
