# CYSwiftTemplate 版本迭代记录与演进计划

> 本文档记录 CYSwiftTemplate 的版本演进历史、当前状态和未来规划。  
> 版本号遵循 [语义化版本（Semantic Versioning）](https://semver.org/lang/zh-CN/) 规范：`MAJOR.MINOR.PATCH`

---

## 版本策略

| 版本类型 | 递增规则 | 示例 | 说明 |
|---|---|---|---|
| **MAJOR** | 不兼容的 API 变更 | `1.0.0` → `2.0.0` | 破坏性变更，需提供迁移指南 |
| **MINOR** | 向后兼容的功能新增 | `1.0.0` → `1.1.0` | 新增功能，不破坏现有代码 |
| **PATCH** | 向后兼容的 Bug 修复 | `1.0.0` → `1.0.1` | 仅修复问题，不新增功能 |

### 发布流程

```bash
# 1. 确保所有测试通过
swift test

# 2. 打标签
git tag -a 1.0.0 -m "Release 1.0.0"
git push origin 1.0.0

# 3. 创建 GitHub Release
# 在 GitHub 上创建 Release，附带变更说明
```

---

## 版本历史

### [1.0.0] - 2026-08-10

**首个正式发布版本** — 核心功能完整，98 个测试全部通过。

#### ✨ 新增功能

**架构与基础设施**
- 7 个 SPM Library 模块化架构（CYAppCore / CYAppNetwork / CYAppImage / CYFeedbackStyle / CYAppDesignSystem / CYAppUI / CYAppPersistence）
- Swift 6 严格并发安全（`swiftLanguageModes: [.v6]`）
- iOS 18 + macOS 15 部署目标
- Factory DI 依赖注入框架集成
- GitHub Actions CI 流水线（build + test + lint）

**网络层（CYAppCore + CYAppNetwork）**
- `CYEndpoint` 协议：类型安全的 API 定义
- `CYNetworkClientProtocol`：协议驱动的网络客户端
- `CYAPIResponse<T>`：统一响应包装，自动解包
- `CYBusinessCodePolicy`：可配置的业务状态码策略
- Token 自动刷新 + 401 重放（Actor 隔离，并发安全）
- 请求去重（Actor 隔离，防止重复请求）
- 请求/响应拦截器链
- 文件上传/下载支持

**状态管理（CYAppUI）**
- `CYAppState`：全局状态容器（@Observable）
- `CYBaseViewModel`：页面级状态基类（loading/error/retry）
- `CYPaginatedListViewModel<Item>`：泛型分页列表
- `CYAppRouter`：多 Tab NavigationStack 路由

**UI 组件库（CYAppDesignSystem + CYAppUI）**
- 主题系统：`CYAppColor` / `CYAppFont` / `CYAppDimens`
- 反馈组件：Toast / Loading / Alert / SnackBar / BottomSheet
- 基础组件：Button / TextField / SearchBar / VerificationCode
- 列表组件：ListRow / SectionHeader / PaginatedList
- 展示组件：Badge / Tag / Card / EmptyState / Shimmer
- 功能组件：Onboarding / RemoteImage / MediaPicker / ShareSheet

**工具与辅助（CYAppCore）**
- `CYKeychainHelper`：Keychain 安全存储
- `CYCacheManager`：Actor 隔离缓存（内存 + 磁盘 + TTL）
- `CYBiometricAuth`：Face ID / Touch ID / Optic ID
- `CYFormValidator`：声明式表单验证
- `CYPermissionManager`：统一权限管理（相机/相册/定位/通知）
- `CYNetworkMonitor`：NWPathMonitor 网络状态监听
- `CYDeepLinkHandler`：深链接处理
- `CYHapticFeedback`：触觉反馈
- `CYDebouncer` / `CYThrottler`：防抖/节流
- `CYLogger`：os.Logger 封装
- 全量本地化（en + zh-Hans，60+ key）

**持久化（CYAppPersistence）**
- SwiftData `@Model` + `ModelContainer`
- Repository 模式（CRUD + 分页 + 搜索）
- 内存/磁盘双模式

**测试**
- 98 个单元测试，覆盖 Core / Network / UI / DesignSystem / FeedbackStyle
- Mock 实现：NetworkClient / AuthService / AnalyticsService / ToastManager / LoadingManager

#### 🐛 修复问题

- `CYAppColor.primary` 深色模式白底白字
- `SkeletonRow.widthRatio` 无效
- `AppStorageHelper.clearAll()` 跨进程清理
- `BiometricAuth.localizedFallbackTitle` 语义错误
- `ExampleApp` 未注册 `imageLoader` 崩溃
- `CYNetworkClient` 401 无限重试循环
- `LoadingManager` 并发请求提前关闭
- `AlertManager` 连续调用覆盖
- `CYAppState` 可观察性（@ObservationIgnored 移除）
- 上传 API 协议与实现不一致
- 核心层硬编码中文（全量本地化）
- 请求去重键复杂 body 冲突
- `CYThrottler` trailing 定时器叠加
- `TypewriterModifier` 视图消失后继续执行
- `DateFormatter` 重复创建（缓存优化）
- `RemoteImageView` 冗余 `retryCount`

#### 📚 文档

- README.md：完整使用指南（916 行）
- REVIEW_AND_ROADMAP.md：评审报告与路线图
- DocC：CYAppCore API 文档
- ExampleApp：3 Tab 可运行 Demo

---

## 未来版本规划

### [1.0.1] - 计划 2026-08-24（1-2 周后）

**主题：配置化与错误处理增强**

#### 计划功能

- [ ] `CYAppConstants` 可注入配置
  - 缓存目录名、Keychain service、分页大小等可通过 `CYAppConfiguration.configure(...)` 覆盖
  - 业务方无需修改模板源码
  
- [ ] Keychain 错误处理增强
  - `save` / `read` / `delete` 返回 `Result` 或 `@discardableResult Bool`
  - 使用 `CYLogger` 统一记录失败
  - 增加 `kSecAttrAccessible` 配置（WhenUnlocked / AfterFirstUnlock）
  
- [ ] 缓存错误处理增强
  - `CacheManager` 写入失败返回错误而非静默忽略
  - 增加磁盘空间检查
  
- [ ] 提取 `CYLoadingIndicator` 公共组件
  - `CYBaseView` 与 `CYLoadingOverlay` 复用同一组件
  - 消除重复代码

#### 验收标准

- 配置化覆盖所有硬编码常量
- Keychain/缓存错误可观测
- 无重复 Loading 实现
- 98+ 测试全部通过

---

### [1.1.0] - 计划 2026-09-07（2-3 周后）

**主题：测试增强与组件完善**

#### 计划功能

- [ ] 网络层测试覆盖率 70%+
  - `CYNetworkClient` 完整测试（上传/下载/拦截器/超时）
  - 使用 `URLProtocol` mock 或 Alamofire `Session` mock
  
- [ ] 图片层测试
  - `CYKingfisherImageLoader` 测试
  - `CYDefaultImageLoader` 测试
  
- [ ] 权限管理测试
  - `CYPermissionManager` 状态流转
  - 各权限类型（相机/相册/定位/通知）测试
  
- [ ] 持久化测试
  - `CYBookmarkRepository` CRUD 测试
  - SwiftData 内存 `ModelContainer` 测试
  
- [ ] 测试隔离全局单例
  - `setUp` / `tearDown` 统一重置机制
  - 支持注入独立实例到测试上下文
  - 测试可并行执行
  
- [ ] 新增业务组件
  - 导航栏组件（自定义 NavigationBar）
  - 图片轮播组件（Carousel）
  - 表单构建器（FormBuilder）

#### 验收标准

- 测试覆盖率 70%+
- 测试可并行执行，无全局状态冲突
- 新增组件有 Preview + 单测 + 文档
- 100+ 测试全部通过

---

### [1.2.0] - 计划 2026-10-05（1 月后）

**主题：CI 增强与示例完善**

#### 计划功能

- [ ] CI 验证 iOS 模拟器
  - GitHub Actions 增加 iOS 模拟器构建步骤
  - ExampleApp 在模拟器上运行验证
  
- [ ] ExampleApp 完整演示
  - 登录页面（表单验证 + 认证服务）
  - 列表页面（分页 + 下拉刷新 + 搜索）
  - 详情页面（路由 + 远程图片）
  - 设置页面（主题切换 + 语言切换 + 持久化）
  - 主题切换实时演示（`appState.theme = .dark`）
  
- [ ] SwiftData 迁移示例
  - V1 → V2 版本化迁移计划
  - 数据迁移策略演示
  
- [ ] App Intents 支持
  - Siri Shortcuts 模板
  - Widget 模板（至少一个）
  
- [ ] 更多业务组件
  - 图表组件（Charts 封装）
  - 二维码扫描组件
  - 文件选择器组件

#### 验收标准

- CI 绿，包含 iOS 模拟器构建
- ExampleApp 演示完整业务流程
- SwiftData 迁移示例可运行
- 至少一个 Widget + 一个 App Intent
- 120+ 测试全部通过

---

### [2.0.0] - 计划 2026-12（远期）

**主题：现代化与多平台**

#### 计划功能

- [ ] Swift Testing 框架迁移
  - 部分测试迁移到 Swift Testing（`@Test` 宏）
  - 演示新旧框架共存
  
- [ ] DocC 托管
  - GitHub Pages 托管 API 文档
  - 所有 public API 有 DocC 注释
  
- [ ] 性能基准测试
  - 缓存/网络/序列化性能测试
  - 防止性能退化
  
- [ ] visionOS 适配
  - 核心组件 visionOS 兼容
  - 空间计算 UI 模板
  
- [ ] watchOS 适配（可选）
  - 核心工具 watchOS 兼容
  - Complication 模板
  
- [ ] 安全审计
  - 依赖扫描（无已知 CVE）
  - Keychain 配置审查
  - 代码安全审查

#### 破坏性变更（需迁移指南）

- 测试框架从 XCTest 迁移到 Swift Testing（部分）
- 可能调整模块依赖关系
- 可能废弃部分 API（提供替代方案）

#### 验收标准

- Swift Testing 测试占比 50%+
- DocC 在线文档可访问
- 性能基准报告
- visionOS 编译通过
- 安全审计报告
- 提供 1.x → 2.x 迁移指南

---

## 版本对比矩阵

| 版本 | 发布日期 | 测试数量 | 覆盖率 | 组件数量 | 平台支持 |
|---|---|---|---|---|---|
| 1.0.0 | 2026-08-10 | 98 | ~60% | 30+ | iOS 18, macOS 15 |
| 1.0.1 | 2026-08-24 (计划) | 100+ | ~65% | 30+ | iOS 18, macOS 15 |
| 1.1.0 | 2026-09-07 (计划) | 120+ | 70%+ | 35+ | iOS 18, macOS 15 |
| 1.2.0 | 2026-10-05 (计划) | 140+ | 75%+ | 40+ | iOS 18, macOS 15 |
| 2.0.0 | 2026-12 (计划) | 160+ | 80%+ | 45+ | iOS 18, macOS 15, visionOS |

---

## 迁移指南

### 1.0.0 → 1.0.1

**无破坏性变更。** 所有 API 向后兼容。

#### 新增配置项（可选）

```swift
// 1.0.1 新增：可覆盖 AppConstants 默认值
CYAppConfiguration.configure(
    environment: .production,
    baseURL: "https://api.example.com",
    constants: CYAppConstantsOverride(
        cacheDirectoryName: "MyAppCache",
        keychainService: "com.myapp.keychain",
        defaultPageSize: 30
    )
)
```

#### Keychain API 变更（可选）

```swift
// 1.0.0: 静默失败
CYKeychainHelper.standard.save(token, service: "com.app", account: "token")

// 1.0.1: 返回结果（可选使用）
let result = CYKeychainHelper.standard.save(token, service: "com.app", account: "token")
if case .failure(let error) = result {
    CYLogger.security.error("Keychain save failed: \(error)")
}
```

---

### 1.x → 2.0.0

**破坏性变更。** 需按迁移指南调整代码。

#### 测试框架迁移（可选）

```swift
// 1.x: XCTest
import XCTest
final class MyTests: XCTestCase {
    func testExample() {
        XCTAssertEqual(1 + 1, 2)
    }
}

// 2.0: Swift Testing（推荐）
import Testing
@Test func example() {
    #expect(1 + 1 == 2)
}
```

#### 废弃 API 列表

| 废弃 API | 替代方案 | 废弃版本 |
|---|---|---|
| （暂无） | — | — |

---

## 贡献者指南

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

---

## 版本发布检查清单

### PATCH 版本（1.0.x）

- [ ] Bug 已修复
- [ ] 新增测试覆盖修复场景
- [ ] `swift test` 全部通过
- [ ] `swiftlint lint --strict` 无错误
- [ ] CHANGELOG.md 已更新
- [ ] Git tag 已创建并推送

### MINOR 版本（1.x.0）

- [ ] 新功能已实现
- [ ] 新增测试覆盖新功能
- [ ] 文档已更新（README / DocC）
- [ ] ExampleApp 已更新（如适用）
- [ ] `swift test` 全部通过
- [ ] `swiftlint lint --strict` 无错误
- [ ] CHANGELOG.md 已更新
- [ ] Git tag 已创建并推送
- [ ] GitHub Release 已创建

### MAJOR 版本（x.0.0）

- [ ] 所有 MINOR 检查项
- [ ] 迁移指南已编写
- [ ] 废弃 API 已标记（`@available(*, deprecated)`）
- [ ] 破坏性变更已在 CHANGELOG 中明确标注
- [ ] 已通知用户迁移

---

## 附录：版本号示例

```
1.0.0       # 首个正式版本
1.0.1       # 修复 Bug
1.0.2       # 再修复一个 Bug
1.1.0       # 新增功能
1.1.1       # 修复新功能的 Bug
1.2.0       # 再新增功能
2.0.0       # 破坏性变更
2.0.1       # 修复破坏性变更的 Bug
2.1.0       # 破坏性变更后的新功能
```

---

*本文档由 OpenCode 生成，随项目迭代持续更新。*
