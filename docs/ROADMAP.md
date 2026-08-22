# 路线图

> 本文档记录 CYSwiftTemplate 的后续开发计划与版本规划。已发布的变更记录请查看 [CHANGELOG](../CHANGELOG.md)。

---

## 当前项目优化执行状态

> 这一部分是“当前最新状态”，不是长期愿景。它会随着本项目的真实进度更新。
>
> 当前原则：一次只做一类事情，做完一项再进入下一项；在模板主干稳定前，不进入 `ExampleApp`。

### 当前进度

- [x] Step 0：确认边界
- [x] Step 1：确认规则和入口文档
- [x] Step 2：整理模板目录和结构
- [x] Step 3：审查模板主干代码
- [x] Step 4：只修当前主题的问题
- [x] Step 5：立即验收
- [ ] Step 6：确认是否进入下一阶段

### 现阶段说明

- 已完成的内容：`docs/TEMPLATE_RULES.md`、`README.md`、`docs/GETTING_STARTED.md` 的定位与结构已调整；`CYAppState` 的 unused-result 告警已消除；`CYAppCore`、`CYAppUI`、`CYAppDesignSystem`、`CYAppNetwork`、`CYAppPersistence` 已完成主干审查；环境、日志、安全区等若干细节已统一。
- 当前重点：继续补主干细节，优先找可统一的默认值、环境开关和命名一致性问题。
- 当前不做：`ExampleApp` 的扩展与大改。

### Step 0：确认边界

- 先明确本轮只优化模板主干，不做 `ExampleApp` 扩展
- 先确认本轮只处理一个主题，不同时改多个方向
- 先确认本轮修改目标是“更稳、更清楚、更易接入”

### Step 1：确认规则和入口文档

- 检查 `docs/TEMPLATE_RULES.md` 是否足够明确
- 检查 `README.md` 是否只承担入口页职责
- 检查 `docs/GETTING_STARTED.md` 是否只承担接入指南职责
- 检查 `docs/ARCHITECTURE.md`、`docs/ROADMAP.md`、`docs/REVIEW.md` 是否与当前代码一致

### Step 2：整理模板目录和结构

- 确认 `Sources/`、`docs/`、`Package.swift`、`ExampleApp/` 的职责边界
- 先把目录结构和文件职责写清楚，再考虑补功能
- 如果结构有歧义，优先更新文档，不先改业务代码

### Step 3：审查模板主干代码

- 先审 `CYAppCore`
- 再审 `CYAppUI`
- 再审 `CYAppDesignSystem`
- 之后再审 `CYAppNetwork` 与 `CYAppPersistence`
- 重点找是否有分层混乱、静默吞错、默认值不清晰、命名不统一

### Step 4：只修当前主题的问题

- 一次只修一类问题，例如“文档一致性”或“错误处理”
- 修完当前问题后不要顺手引入新的功能扩展
- 如果发现要改的内容会影响别的主题，先暂停并重新拆分任务

### Step 5：立即验收

- 每完成一类修改，立即执行构建、测试或诊断检查
- 验收不过就先修当前问题，不进入下一步
- 通过后再记录变更结果

### Step 6：确认是否进入下一阶段

- 当前阶段全部完成后，再考虑 `ExampleApp`
- `ExampleApp` 只在模板主干稳定后创建或大改
- 如果模板规则还在变，先继续稳定主干，不提前扩示例

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
| 1.0.1 | 计划中 | 100+ | ~65% | 30+ | iOS 18, macOS 15 |
| 1.1.0 | 计划中 | 120+ | 70%+ | 35+ | iOS 18, macOS 15 |
| 1.2.0 | 计划中 | 140+ | 75%+ | 40+ | iOS 18, macOS 15 |
| 2.0.0 | 远期 | 160+ | 80%+ | 45+ | iOS 18, macOS 15, visionOS |

---

## 开发执行流程（必须按顺序执行）

> 这部分不是愿景，而是后续每轮开发都要遵守的执行顺序。原则是：**一次只做一类事情，做完一项再进入下一项**，避免边改边发散、边修边加需求。

### Step 1：先确认本轮目标

**要做什么**
- 明确本轮只处理一个主题，例如：文档、目录结构、核心代码、测试、示例
- 确认本轮不同时混入多个主题

**完成标准**
- 能用一句话说清楚本轮要解决什么问题
- 能明确本轮不碰什么内容

### Step 2：先审查，不直接扩展

**要做什么**
- 先读相关文件
- 先找不符合规范的地方
- 先记录问题，不急着改动大量代码

**完成标准**
- 已确认当前文件与规范之间的差异
- 已确定修改范围

### Step 3：一次只修一个文件组

**要做什么**
- 例如本轮只修文档，或只修 `CYAppCore`，或只修 `CYAppUI`
- 不在同一轮里同时做模板主干、示例、路线图和架构大改

**完成标准**
- 本轮修改只集中在一个明确范围内
- 不引入额外的无关改动

### Step 4：改完立即验收

**要做什么**
- 每完成一类修改，就立刻执行构建、测试或 lint
- 确认没有引入新问题

**完成标准**
- 本轮修改有明确的验证结果
- 若验证失败，先修复当前问题，不进入下一步

### Step 5：更新文档与状态记录

**要做什么**
- 同步更新 README、接入文档、路线图或评测文档
- 记录本轮已经完成什么、还剩什么

**完成标准**
- 文档和代码保持一致
- 未来继续开发时能看懂本轮做了什么

### Step 6：确认是否进入下一主题

**要做什么**
- 只有当前主题完全完成，才进入下一个主题
- 例如先完成模板规则和结构，再做 ExampleApp

**完成标准**
- 当前主题没有遗留问题
- 下一主题有明确输入，不是临时起意

---

## Phase 1：发布质量修整（约 1 周）

> 对应版本 [1.0.1] - 计划 2026-08-24
>
> 执行要求：本阶段只处理“模板主干稳定性”，不做 ExampleApp 扩展。

**主题：配置化与错误处理增强**

| 任务 | 验收标准 |
|---|---|
| 显式声明 FactoryKit 依赖 | Network/Image 不依赖 Core 的传递依赖仍可干净构建 |
| 存储错误可观测 | Keychain/缓存失败可被上层处理并结构化记录 |
| `CYAppConstants` 可注入配置 | 缓存目录名、Keychain service、分页大小等可通过 `.configure(...)` 覆盖 |
| Keychain 错误处理增强 | `save` / `read` / `delete` 返回 `Result`，增加 `kSecAttrAccessible` 配置 |
| 缓存错误处理增强 | `CacheManager` 写入失败返回错误而非静默忽略 |
| 消除编译告警 | `AppState` 无 unused-result 告警；评估并记录第三方 Kingfisher 告警 |
| 提取 `CYLoadingIndicator` 公共组件 | `CYBaseView` 与 `CYLoadingOverlay` 复用同一组件 |
| 文档校准 | README、DocC、报告中的模块数、依赖与测试统计一致 |

---

## Phase 2：可信测试与 CI（约 2–3 周）

> 对应版本 [1.1.0] - 计划 2026-09-07
>
> 执行要求：只有在 Phase 1 完成并验收后，才允许进入本阶段。

**主题：测试增强与组件完善**

| 任务 | 验收标准 |
|---|---|
| 网络层测试覆盖率 70%+ | 上传/下载/拦截器/超时有确定性测试（URLProtocol mock 或 Alamofire Session mock） |
| 图片层测试 | `CYKingfisherImageLoader` / `CYDefaultImageLoader` 测试 |
| 权限管理测试 | `CYPermissionManager` 状态流转 + 各权限类型测试 |
| 持久化测试 | `CYBookmarkRepository` CRUD + SwiftData 内存 ModelContainer 测试 |
| 隔离全局单例 | `setUp` / `tearDown` 统一重置机制，测试可并行执行 |
| 新增业务组件 | 导航栏组件 / 图片轮播组件 / 表单构建器 |
| iOS CI | 至少构建 ExampleApp 和主要 targets 到固定 iOS Simulator |
| 固定工具链 | Xcode/SwiftLint 版本明确，可重复执行 |

---

## Phase 3：模板体验与生产治理（持续）

> 对应版本 [1.2.0] - 计划 2026-10-05
>
> 执行要求：只有在 Phase 2 完成并验收后，才允许进入本阶段。ExampleApp 的完整完善在本阶段进行。

**主题：CI 增强与示例完善**

| 任务 | 验收标准 |
|---|---|
| CI 验证 iOS 模拟器 | GitHub Actions 增加 iOS 模拟器构建步骤 |
| ExampleApp 完整演示 | 登录、列表、详情、设置、图片与持久化均可在 ExampleApp 跑通 |
| 主题切换实时演示 | `appState.theme = .dark` 在 ExampleApp 中可切换 |
| SwiftData 迁移示例 | V1 -> V2 版本化迁移计划与演示 |
| App Intents 支持 | Siri Shortcuts 模板 + 至少一个 Widget 模板 |
| 更多业务组件 | 图表组件（Charts 封装）/ 二维码扫描 / 文件选择器 |
| 性能与安全基线 | 缓存/网络基准、依赖扫描、Keychain 策略与隐私清单形成文档 |
| API 文档完善 | 每个公共模块具有自己的 DocC 入口及关键 public API 注释 |

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
| P2 | `ExampleApp` 未展示主题切换、图片、持久化、登录与错误重试 | 1.2.0 |
| P2 | Keychain 可访问级别、日志 subsystem 等仍未统一配置 | 1.1.0 |
| P2 | iOS 运行级测试尚未覆盖 | 1.1.0 |
| P2 | macOS/iOS 构建矩阵仍缺少正式验证记录 | 1.1.0 |

---

## 本阶段执行约束

- 每次只处理一个主题，不同时改多个主题的内容。
- 每完成一项，就必须执行一次验证并确认结果。
- 本阶段未完成前，不进入 ExampleApp 相关改动。
- 若发现需要调整流程，先更新本节约束，再继续改代码。

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
