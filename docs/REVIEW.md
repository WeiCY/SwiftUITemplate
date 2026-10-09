# 工程化评测

> 评测日期：2026-10-09 ｜ 适用版本：1.2.x
>
> 范围：模块边界、启动配置、Core / UI / Network / Image / Persistence、ExampleApp、测试与文档。
> 验证：Swift 6 Package 构建通过；Package 测试全部通过（数量见 [CHANGELOG](../CHANGELOG.md)）。
>
> **定位声明**：本评测优先按“个人 / 中小团队 SwiftUI **App Factory**”定位评价，而不是按大型企业平台 / SDK 标准评价。重点看新 App 起步速度、模块可裁剪性、宿主业务边界、依赖注入清晰度、ExampleApp 可复制性、公共 API 稳定性、文档一致性与真实 App 升级成本。
>
> 本文随版本更新；历史快照见 [archive/REVIEW.md](archive/REVIEW.md)（不代表当前代码）。

## 结论

工程稳定在“可组合 App Factory”阶段：7 个 Library 依赖单向，Network / Image / Persistence 可选，启动配置集中在宿主 `AppConfig` / `AppBootstrap`，账号、业务模型与固定 Tab 已从 Foundation 移出，ExampleApp 是可复制的新项目范例。当前**没有阻塞性架构问题**。

| 指标 | 评分 |
|---|---:|
| 综合工程质量 | **8.8 / 10** |
| App Factory 适配度 | **9.0 / 10** |

| 维度 | 评分 | 评价 |
|---|---:|---|
| 模块边界 | 9.1 | 7 个 Library；可选模块隔离清晰，业务模型已移出 Foundation。 |
| DI / Composition Root | 9.2 | Base DI 与 `NetworkProviding` 拆分；`AppDependencies` 显式构造并注入。 |
| Network | 9.0 | 默认无鉴权，端点策略清楚，凭证恢复 single-flight，账号语义归宿主。 |
| Persistence | 8.8 | `CYPersistenceController` + Repository 协议通用；Schema 归宿主。 |
| UI / DesignSystem | 8.5 | 默认 DesignSystem 实用，但仍是静态 Token，只支持主/强调色覆写。 |
| ExampleApp | 9.3 | 覆盖网络 / loading / error / retry / 路由 / SwiftData / 设置，可直接复制。 |
| 可裁剪性 | 8.9 | 离线 App 可不引入 Network；单 Tab App 不强制多 Tab。 |
| 文档结构 | 9.0 | 6 篇核心文档职责单一，历史资料归档。 |
| 文档一致性 | 8.8～9.0 | 已收敛；需持续随公共 API 同步。 |
| App Factory 适配 | 9.0 | 新项目起步快，宿主边界清楚。 |

## 已达到的能力

1. 离线 App 可以不选择 `CYAppNetwork`；Image 与 Persistence 同样按需。
2. `networkClient` 拆到可选的 `NetworkProviding`，离线 Feature 只依赖 `DIContainerProtocol`（1.2.0）。
3. `CYAppConfig` 只描述 Core，宿主 `AppBootstrap` 配置框架、`AppDependencies` 构造业务依赖。
4. 网络端点默认 `.none`，无需账号的 App 没有认证成本。
5. Router 管理任意 `CYTabID`，Persistence 接收宿主 Schema。
6. ExampleApp 是完整接入范例，而非组件 Demo。

## 主要问题

### P0

**当前没有阻塞性架构问题。** 模板已经可以实际用于新项目。

### P1

- 用真实的离线 App + 网络 App 验证从创建到 TestFlight 的完整流程。
- `CYAppCore` 不继续膨胀：新能力必须先证明跨 App 高频复用。
- `GETTING_STARTED` / `ExampleApp` / `ARCHITECTURE` 持续保持一致。
- Image / Permission / Persistence 测试补强。
- Feedback / DI 单例测试隔离（`setUp` / `tearDown` 统一重置）。
- iOS App target / 真机生命周期验证（Package 测试不能替代）。

### P2 / Future

- Theme Token 动态注入 / Theme Pack。
- Crash / Observability 方案。
- 性能基准测试与完整 UI Test Matrix。
- 多 App（5/10/20）版本治理、迁移日志与批量升级工具。
- 自动生成器 / 复杂发布工具。
- visionOS / watchOS 适配。

> 以上 P2 并非当前模板缺陷，而是规模扩大后才可能需要的能力。

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

当前最重要的不是继续拆模块或增加功能，而是验证这些边界能否减少新 App 的基础设施工作，并保持后续升级可迁移。
