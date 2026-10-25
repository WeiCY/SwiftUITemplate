# 高优先级边界修复与迁移（2026-10-25）

## 定位权限

`CYLocationPermission` 改为 MainActor 隔离，CLLocationManager 也只在主 actor 创建/调用。
系统 delegate 仅通知主 actor，主 actor 读取当前授权状态，不跨 actor 传递 CLLocationManager。
内部驱动协议用于测试，不新增公开系统服务框架。

- 多个 request 共享一次系统请求，每个调用者有独立 continuation。
- notDetermined 回调不视为完成；authorized/denied/restricted 才恢复所有等待者。
- 取消只移除本次等待者。协议返回值保持不变：返回取消时的当前授权状态，可能为 notDetermined；调用者可额外检查 Task.isCancelled。
- 已取消的任务不弹授权框。所有等待者取消后，系统弹窗继续存在，后续请求复用未完成的系统请求。
- 不自动申请 Always 权限，也不关闭系统授权界面。用途文案仍由宿主提供。

**迁移**：在 MainActor 创建实例，或在后台使用 `let permission = await CYLocationPermission()`；request/status 本来就是 async。
`CYPermissionManager` 已在 MainActor，无需修改现有调用。公开类型不再充当 CLLocationManagerDelegate；delegate 实现属于内部驱动。

## 网络监听

`CYNetworkMonitor` 改为 MainActor + Observable，取消 unchecked Sendable 与第二套状态队列。
所有公开状态改为 private(set)，只能由监听更新；跨 actor 读写需 await 或 MainActor.run。
每次 start/stop 都更新代次；旧实例的延迟回调不能污染重新启动后的状态。
重复 start 不创建第二个监听器，每次真正重新 start 使用新的 NWPathMonitor。

初始 isConnected=true 保留兼容性，但**不是已测得的联网状态**；新增 hasReceivedUpdate。
stop 保留最后值供展示，同时将 hasReceivedUpdate=false。监听判断的是系统路径，不保证后端可达，不应阻止实际请求尝试。

```swift
// compile-check: network-monitor-main-actor
import CYAppCore

@MainActor
func beginPathObservation() {
    let monitor = CYNetworkMonitor.shared
    monitor.startMonitoring()
    if monitor.hasReceivedUpdate, !monitor.isConnected {
        // 宿主可显示离线提示；不要将路径判断作为请求的唯一前置条件。
    }
}
```

**迁移**：删除业务中对 isConnected/connectionType 等属性的直接赋值。测试在自己的网络状态协议/替身中模拟，不修改系统单例。

## 日志

- CYCoreBootstrap 配置全局默认级别，已有与未来新建分类都会跟随。
- `logger.setMinimumLevel` 仍表示该实例的显式覆盖，优先于全局默认；`resetMinimumLevel()` 恢复跟随。
- `CYLogger.setGlobalMinimumLevel` 设置全局默认；`globalMinimumLevel` 和 `minimumLevelOverride` 支持测试保存/恢复。
- 消息插值默认使用 OSLog private。仅经过检查、不会含用户数据的分类可 `CYLogger(category: "Lifecycle", publicMessages: true)`。
- private 是统一日志的隐私标记，不是加密，也不代表调试时一定不可见；调用方仍不应传入密码、Token 或任意用户模型。
- Analytics 的敏感字段日志已在上一轮移除，本轮延续该行为。

**迁移**：想控制全部分类时使用 Bootstrap 或新的全局方法；过去调用 `CYLogger.shared.setMinimumLevel` 仍然只覆盖 shared。
需要查看生产日志的宿主应先梳理固定公开消息，而不是统一打开 public。

## 包级隐私清单

`Sources/CYAppCore/Resources/PrivacyInfo.xcprivacy` 通过已有 `.process("Resources")` 打包。
清单声明模板自身不跟踪、不向设备外收集数据，覆盖以下预期使用：

| API 类别 / 原因 | 源码与用途约束 |
|---|---|
| UserDefaults / CA92.1 | ThemeManager、LocalizationManager、AppStorageHelper；只读写宿主 App 的偏好 |
| SystemBootTime / 35F9.1 | Debouncer.swift 中 Throttler；仅计算事件时间间隔，不上传启动时间 |
| DiskSpace / 85F4.1、E174.1 | FileManager 扩展；仅向用户显示空间或决定是否能写入，数据不用于指纹识别/传出设备 |
| FileTimestamp / C617.1 | FileManager 的文件属性访问；默认仅覆盖 App 容器内文件元数据，不将时间戳传出设备 |

公开 FileManager 工具可接收宿主路径，无法替宿主保证所有用途；宿主访问用户选定的外部文档、改变数据用途或接入分析 SDK 时，必须重新核对适用原因与数据收集声明。
第三方包自己的隐私清单由对应包提供，不能用 Core 清单代替；宿主应检查最终归档的隐私报告和资源包内容。

参考：[Apple Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。
本轮尝试读取官方页面数据得到 HTTP 403，未能在线核对当前完整清单；以上代码与用途映射需在发布前对照当时 Apple 规则复核。
清单结构校验通过不等于归档检查或 App Store 审核通过。

## 验证

新增 `PlatformBoundaryTests` 6 项 XCTest：并发授权、取消单个等待者、预取消不请求、网络代次/停止、全局日志与覆盖、Core Bundle 隐私资源。
这些测试和上一轮 8 项 UsageSafetyTests 均尚未在当前环境执行；没有 Swift/Xcode，不能声明 Swift 类型检查通过。
本轮可执行检查：隐私 plist 四类结构及唯一性、71 个公开 UI/支撑类型矩阵、6 项 Python 生成器回归、git diff --check。

macOS 下一步执行：

```bash
swift test --filter PlatformBoundaryTests
swift test --filter UsageSafetyTests
swift test
swiftlint lint --strict --quiet
python3 scripts/verify-doc-examples.py
```

真机还需验收首次定位弹窗、取消等待后授权、系统设置中撤销/恢复权限、网络断连/重连；日志 private 的实际显示及隐私归档报告需 Apple 工具链检查。
