# 工程化评测

> 评测日期：2026-10-09 ｜ 适用版本：1.2.x
>
> 范围：模块边界、启动配置、Core / UI / Network / Image / Persistence、ExampleApp、测试与文档。
> 验证：Swift 6 Package 构建通过；Package 测试全部通过（数量见 [CHANGELOG](../CHANGELOG.md)）。
>
> 本文是**随版本更新**的评测结论，不是长期不变的评价。历史快照见 [archive/REVIEW.md](archive/REVIEW.md)（不代表当前代码）。

## 结论

工程稳定在“可组合 App Factory”阶段：7 个 Library 依赖单向，Network / Image / Persistence 可选，启动配置集中在宿主 `AppConfig` / `AppBootstrap`，账号、业务模型与固定 Tab 已从 Foundation 移出。适合作为个人和中小团队多个独立 App 的基础底座，但不宜称为完整生产平台或自动生成器——Theme 注入、发布流水线、iOS 运行级验证和多 App 版本治理仍需真实项目推动。

综合评分：**8.8 / 10**。

| 维度 | 评分 | 评价 |
|---|---:|---|
| 模块化与边界 | 9.0 | 7 个 Library；Network、Image、Persistence 可选，业务模型已移出 Foundation。 |
| 启动与配置 | 8.5 | Core Config 与宿主 Bootstrap 分工清楚，复用现有配置入口。 |
| 业务解耦 | 9.0 | Core 不含 User/Auth、Bookmark/Tag 或固定业务 Tab。 |
| 网络设计 | 9.0 | 默认无鉴权，端点策略清楚，凭证恢复 single-flight，账号语义归宿主。 |
| UI 与 Theme | 7.8 | 默认 DesignSystem 实用，但仍是静态 Token，只支持主/强调色覆写。 |
| 可测试性 | 8.7 | 覆盖关键边界；仍缺 iOS 运行级测试。 |
| 文档与示例 | 8.8 | 文档已收敛为 5 篇核心 + 路线图；ExampleApp 是真实接入范例。 |
| 长期维护 | 8.3 | 方向合理，但 Core 体积、单例和多 App 版本同步需持续控制。 |

## 已达到的能力

1. 离线 App 可以不选择 `CYAppNetwork`；Image 与 Persistence 同样按需。
2. `networkClient` 拆到可选的 `NetworkProviding`，离线 Feature 只依赖 `DIContainerProtocol`（1.2.0）。
3. `CYAppConfig` 只描述 Core，宿主 `AppBootstrap` 组合各模块。
4. 网络端点默认 `.none`，无需账号的 App 没有认证成本。
5. Router 管理任意 `CYTabID`，Persistence 接收宿主 Schema。
6. ExampleApp 覆盖网络 / loading / error / retry / 路由 / SwiftData / 设置，可直接复制为新项目模板。

## 主要问题

### P0

- 新 App 必须从 xcconfig/Info.plist 注入 Base URL，不能沿用 Example 占位值或提交密钥。
- Package 测试不能替代 iOS App target、真机权限、StoreKit 和生命周期验证。

### P1

- DesignSystem 是静态语义 Token，`CYAppColor` 仅支持 `primary` / `accent` 覆写，尚不能自然安装外部 Theme Pack。
- Core 已包含较多 Helper/Manager；新增能力必须证明跨 App 高频复用。
- 全局配置器和 Manager 使用单例；反馈管理器（Toast/Loading/Alert）与 DI 容器尚无统一测试重置机制。
- Analytics 是轻量抽象；Crash 和生产可观测性由宿主选择。
- `OSLog` subsystem/category 尚不能由宿主统一配置。

### P2

- 缺少正式 iOS UI/集成测试矩阵、性能基准、依赖安全与隐私清单审计记录。
- 图片层 / 权限管理 / 持久化测试仍需补强。
- 尚无 5/10/20 个 App 的版本治理、迁移日志和批量升级机制。
- 缺 SwiftData 版本化迁移示例。

## 第三方依赖

| 依赖 | 评价 |
|---|---|
| FactoryKit | 已深入 DI，当前移除收益低；应控制其使用边界。 |
| Alamofire | 隔离在 Optional Network，离线 App 可不链接。 |
| Kingfisher | 隔离在 Optional Image，Core 保留轻量 URLSession 图片加载。 |

当前没有必要为了“纯原生”立即替换依赖。更重要的是不让 Alamofire/Kingfisher 类型泄漏到 Feature 契约。

## 下一步

1. 用一个离线 App 和一个网络 App 走完创建到 TestFlight。
2. 补 iOS target 构建与关键运行级测试。
3. 补图片 / 权限 / 持久化测试，并统一反馈管理器与 DI 容器的测试隔离。
4. `OSLog` subsystem 可配置化。
5. 等多个 App 出现真实重复需求后，再决定 Theme Token、设置组件或发布工具是否进入模板。

当前最重要的不是继续拆模块，而是验证这些边界能否减少新 App 的基础设施工作，并保持后续升级可迁移。
