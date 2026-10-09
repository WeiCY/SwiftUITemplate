# 路线图

> 本文档记录 CYSwiftTemplate 的后续开发计划与版本规划。已发布的变更记录请查看 [CHANGELOG](../CHANGELOG.md)。

---

## 当前状态

> 这一部分是“当前最新状态”，不是长期愿景；它会随真实进度更新。

### 当前进度

- [x] 模板边界与规则文档已确定
- [x] 目录结构与主干代码审查完成
- [x] 网络层重构，随 1.1.0 发布
- [x] 1.2.0 App Factory 基线（DI 能力拆分 + ExampleApp 接入范例）
- [ ] 后续：测试补强、iOS 运行级测试、Logger subsystem 可配置

### 现阶段说明

- **1.2.0（2026-10-09）已发布**：`networkClient` 拆分为可选能力协议 `NetworkProviding`；ExampleApp 重构为真实接入范例（网络 / loading / error / retry / 路由 / SwiftData / 设置），
  当前 Package 测试全部通过（数量见 [CHANGELOG](../CHANGELOG.md)）。
- **网络层能力升级（1.1.0，2026-08-23）已完成**：`CYResponseStrategy` + `send` API、`requestVoid`/`requestData`/泛型 `request(body:)`、`upload(parts:)` 多文件上传、上传/下载进度与取消传播、`.cancelled` 取消识别、日志脱敏、Token 刷新边界、空响应/204 支持。详见 [CHANGELOG](../CHANGELOG.md) 与 [归档：网络重构执行记录](./archive/NETWORK_REFACTOR_PLAN.md)。
- 发布质量修整（原 1.0.1 计划）内容已提前完成并随 1.1.0 发布：FactoryKit 依赖显式声明、`CYAppConstants` 可注入配置、Keychain 错误处理 `Result` + `kSecAttrAccessible` 配置、缓存错误可观测、SwiftLint 版本固定。
- 测试隔离：`CYAppState` 测试注入内存版主题/多语言管理器替身并清理 UserDefaults 持久化键，跨用例、跨运行可复现；iOS Simulator 构建改为 `swift build --sdk/--triple` 交叉编译验证（无需 `.xcodeproj`）。
- 当前重点：测试补强（图片层 / 权限管理 / 持久化 / 反馈管理器单例隔离）、iOS 运行级测试、Logger subsystem 可配置化。

---

## 版本策略

版本号遵循 [语义化版本（Semantic Versioning）](https://semver.org/lang/zh-CN/) 规范：`MAJOR.MINOR.PATCH`

| 版本类型 | 递增规则 | 示例 | 说明 |
|---|---|---|---|
| **MAJOR** | 不兼容的 API 变更 | `1.0.0` -> `2.0.0` | 破坏性变更，需提供迁移指南 |
| **MINOR** | 向后兼容的功能新增 | `1.0.0` -> `1.1.0` | 新增功能，不破坏现有代码 |
| **PATCH** | 向后兼容的 Bug 修复 | `1.0.0` -> `1.0.1` | 仅修复问题，不新增功能 |

---

## 版本对比矩阵

| 版本 | 状态 | 测试数量 | 覆盖率 | 组件数量 | 平台支持 |
|---|---|---|---|---|---|
| 1.0.0 | 已发布 (2026-08-10) | 98 | ~60% | 30+ | iOS 18, macOS 15 |
| 1.1.0 | 已发布 (2026-08-23) | 156 | ~70% | 35+ | iOS 18, macOS 15 |
| 1.2.0 | 已发布 (2026-10-09) | 161 | 75%+ | 40+ | iOS 18, macOS 15 |
| 2.0.0 | 远期（待多个真实 App 验证后迭代） | 180+ | 80%+ | 45+ | iOS 18, macOS 15, visionOS |

> 1.0.1 计划已取消：其内容（可配置默认值、Keychain/缓存错误可观测、FactoryKit 依赖显式化等）已完成并随 1.1.0 发布。

---

> 每轮开发的执行顺序与变更纪律见 [TEMPLATE_RULES 第 8 节](./TEMPLATE_RULES.md#8-变更规则)，此处不再重复。

---

## Phase 1：发布质量修整（✅ 已完成，随 1.1.0 发布）

> 原计划对应版本 [1.0.1]（已取消），内容并入 1.1.0（2026-08-23）。

**主题：配置化与错误处理增强**

| 任务 | 状态 |
|---|---|
| 显式声明 FactoryKit 依赖 | ✅ `Package.swift` 中 Network/Image 显式声明，不依赖 Core 传递依赖 |
| 存储错误可观测 | ✅ Keychain/缓存失败返回 `Result` 并结构化记录 |
| `CYAppConstants` 可注入配置 | ✅ `CYAppConfigurationValues` + `.configure(...)` 可覆盖缓存目录名、Keychain service、分页大小等 |
| Keychain 错误处理增强 | ✅ `save` / `read` / `delete` 返回 `Result`，支持 `kSecAttrAccessible` 配置 |
| 缓存错误处理增强 | ✅ `CacheManager` 写入/清除失败返回错误而非静默忽略 |
| 消除编译告警 | ✅ `AppState` 无 unused-result 告警；第三方 Kingfisher `Info.plist` 告警已记录为已知 |
| 提取 `CYLoadingIndicator` 公共组件 | ✅ `CYBaseView` 与 `CYLoadingOverlay` 复用同一组件（`CYAppDesignSystem/Components/LoadingIndicator.swift`），行为一致 |
| 文档校准 | ✅ 本轮完成：ROADMAP、REVIEW、ARCHITECTURE、README 已与 1.1.0 现状同步 |

---

## Phase 2：可信测试与 CI（✅ 网络重构完成；其余项移至 1.2.0）

> 原计划对应版本 [1.1.0]，实际 1.1.0 发布内容为网络层能力升级（Batch 0–16，156/156 测试全绿），
> 原「测试增强与组件完善」中未完成项全部顺延至 1.2.0。

**主题：测试增强与组件完善（1.1.0 完成情况）**

| 任务 | 状态 |
|---|---|
| 网络层测试覆盖率 70%+ | ✅ `NetworkRegressionTests`（34 条）+ `MockNetworkClientTests`，上传/下载/拦截器/取消/去重均有确定性测试（URLProtocol mock） |
| 固定工具链 | ✅ SwiftLint 0.59.1 固定；CI 使用固定 Xcode |
| iOS CI | ✅ 已修复（2026-09-02）：改为 `swift build --sdk/--triple` 交叉编译验证 iOS Simulator 目标，无需 `.xcodeproj`，本地已验证通过 |
| 图片层测试 | ⬜ 移至 1.2.0 |
| 权限管理测试 | ⬜ 移至 1.2.0 |
| 持久化测试 | ⬜ 部分完成（BookmarkRepository CRUD 1 条），移至 1.2.0 补强 |
| 隔离全局单例 | ⬜ 移至 1.2.0 |
| 新增业务组件 | ⬜ 移至 1.2.0 |

---

## Phase 3：测试补强、CI 修复与模板完善（1.2.0 发布后剩余项）

> 1.2.0 已于 2026-10-09 发布（DI 能力拆分 `NetworkProviding` + ExampleApp 接入范例重构）。
> 下列未完成项顺延至后续版本。详见 [CHANGELOG](../CHANGELOG.md)。

**主题：测试补强、CI 修复与模板完善**

| 任务 | 验收标准 |
|---|---|
| 图片层测试 | `CYKingfisherImageLoader` / `CYDefaultImageLoader` 测试 |
| 权限管理测试 | `CYPermissionManager` 状态流转 + 各权限类型测试（注入 mock requester） |
| 持久化测试补强 | `CYBookmarkRepository`/`CYTagRepository` CRUD + 错误路径 + 内存 ModelContainer 测试 |
| 隔离全局单例 | `setUp` / `tearDown` 统一重置机制，测试可并行执行 |
| 新增业务组件 | 导航栏组件 / 图片轮播组件 / 表单构建器 |
| iOS CI 修复与验证 | ✅ 已完成（2026-09-02）：CI 改为 `swift build` 交叉编译，无需 `.xcodeproj`；远程 Actions 待下次推送确认 |
| iOS 运行级测试 | XCUITest / iOS Simulator 运行级测试覆盖关键流程 |
| Logger subsystem 可配置 | 宿主可通过 `.configure(...)` 统一设置 `OSLog` subsystem 与默认 category |
| ExampleApp 接入范例 | ✅ 1.2.0 已重构：网络 / loading / error / retry / 路由 / SwiftData / 设置（Mock 后端可跑通） |
| 主题切换实时演示 | ✅ `SettingsView` 支持主题 / 语言切换 |
| SwiftData 迁移示例 | V1 -> V2 版本化迁移计划与演示 |
| 性能与安全基线 | 缓存/网络基准、依赖扫描、Keychain 策略与隐私清单形成文档 |
| API 文档完善 | 每个公共模块具有自己的 DocC 入口及关键 public API 注释 |
| 多平台构建矩阵 | iOS/macOS 双平台构建与测试矩阵形成正式验证记录 |

---

## 远期：现代化与多平台

> 对应版本 [2.0.0] - 计划 2026-12

**主题：现代化与多平台**

| 任务 | 验收标准 |
|---|---|
| Swift Testing 框架迁移 | 部分测试迁移到 `@Test` 宏，演示新旧框架共存 |
| DocC 托管 | GitHub Pages 托管 API 文档，所有 public API 有注释 |
| 性能基准测试 | 缓存/网络/序列化性能测试，防止性能退化 |
| visionOS 适配 | 核心组件 visionOS 兼容，空间计算 UI 模板 |
| watchOS 适配（可选） | 核心工具 watchOS 兼容，Complication 模板 |
| 安全审计 | 依赖扫描（无已知 CVE）、Keychain 配置审查、代码安全审查 |

### 破坏性变更（需迁移指南）

- 测试框架从 XCTest 迁移到 Swift Testing（部分）
- 可能调整模块依赖关系
- 可能废弃部分 API（提供替代方案）

---

## 已知待改进项

以下问题已识别，将按优先级在后续版本中处理：

| 优先级 | 问题 | 计划版本 |
|---|---|---|
| ~~P1~~ | ✅ iOS Simulator CI 构建步骤已修复（2026-09-02，改为 `swift build` 交叉编译，无需 `.xcodeproj`） | 已完成 |
| ~~P2~~ | ✅ `ExampleApp` 已重构为真实接入范例（网络 / 状态 / 路由 / 持久化 / 设置，1.2.0） | 已完成 |
| P2 | `OSLog` subsystem/category 仍无法由宿主统一配置 | 后续 |
| P2 | 图片层 / 权限管理 / 持久化测试不足；反馈管理器（Toast/Loading/Alert）与 DI 容器无统一测试隔离（AppState/主题/语言隔离已于 2026-09-02 修复） | 后续 |
| P2 | iOS 运行级测试尚未覆盖 | 后续 |
| P2 | macOS/iOS 构建矩阵仍缺少正式验证记录 | 后续 |

---

## 发布流程

```bash
# 1. 确保所有测试通过
swift test

# 2. 打标签
git tag -a 1.0.0 -m "Release 1.0.0"
git push origin 1.0.0

# 3. 创建 GitHub Release，附带变更说明
```

### 发布检查清单

**PATCH 版本（1.0.x）**
- [ ] Bug 已修复
- [ ] 新增测试覆盖修复场景
- [ ] `swift test` 全部通过
- [ ] `swiftlint lint --strict` 无错误
- [ ] CHANGELOG.md 已更新
- [ ] Git tag 已创建并推送

**MINOR 版本（1.x.0）**
- [ ] 新功能已实现
- [ ] 新增测试覆盖新功能
- [ ] 文档已更新（README / DocC）
- [ ] ExampleApp 已更新（如适用）
- [ ] `swift test` 全部通过
- [ ] `swiftlint lint --strict` 无错误
- [ ] CHANGELOG.md 已更新
- [ ] Git tag 已创建并推送
- [ ] GitHub Release 已创建

**MAJOR 版本（x.0.0）**
- [ ] 所有 MINOR 检查项
- [ ] 迁移指南已编写
- [ ] 废弃 API 已标记（`@available(*, deprecated)`）
- [ ] 破坏性变更已在 CHANGELOG 中明确标注
- [ ] 已通知用户迁移

---

## 贡献流程

### 提交 Bug 修复（PATCH）

1. 从 `main` 分支创建 `fix/xxx` 分支
2. 修复问题并添加测试
3. 确保 `swift test` 全部通过
4. 提交 PR，描述修复内容

### 提交新功能（MINOR）

1. 从 `main` 分支创建 `feature/xxx` 分支
2. 实现功能并添加测试
3. 更新文档（README / DocC）
4. 确保 `swift test` 全部通过
5. 提交 PR，描述功能和使用示例

### 提交破坏性变更（MAJOR）

1. 提前在 Issue 中讨论方案
2. 从 `main` 分支创建 `breaking/xxx` 分支
3. 实现变更并提供迁移指南
4. 更新所有文档和示例
5. 确保 `swift test` 全部通过
6. 提交 PR，详细描述变更和迁移步骤
