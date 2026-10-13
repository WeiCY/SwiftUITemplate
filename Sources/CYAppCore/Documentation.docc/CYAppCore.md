# CYAppCore

基础能力层，第三方依赖仅 FactoryKit；权限、Keychain、设备等工具按需桥接 Apple 系统框架。提供协议抽象、工具类和 DI 基础设施。

> **按需引入设计**：HTTP 客户端实现由可选的 `CYAppNetwork` 提供。Core 内置 ``CYDefaultImageLoader``（URLSession）；需要 Kingfisher 缓存和预取时，再引入 `CYAppImage` 并注册。

## 概述

CYAppCore 是 CYSwiftTemplate 的核心骨架，遵循 **协议驱动 + DI 注入** 的设计原则。
Alamofire 客户端与 Kingfisher 图片加载器位于独立可选 target：

- `CYAppNetwork`：`CYNetworkClient` Alamofire 实现
- `CYAppImage`：`CYKingfisherImageLoader` Kingfisher 实现

### 架构分层

```
CYAppCore (基础能力 + FactoryKit)
├── Network      网络协议层（CYEndpoint, CYNetworkClientProtocol, APIResponse）
├── Services     通用分析协议与默认实现（账号/认证/会话由宿主持有）
├── DI           依赖注入（Protocol → Factory）
├── Image        图片加载协议 + URLSession 默认实现
├── Cache        Actor 隔离缓存
├── Managers     Toast / Loading / Alert
├── Permissions  权限管理
├── Logger       多级日志
└── Extensions   Foundation / 系统平台扩展
```

### 接入示例

```swift
import CYAppCore

// 仅使用协议 + 工具，无需 Alamofire/Kingfisher
let cache = CYCacheManager.shared
let logger = CYLogger.shared
CYToastManager.shared.show("操作成功", type: .success)
```

## 默认行为

- 缓存使用 v2 子目录和稳定摘要文件名；旧缓存按未命中处理，nil 与空 namespace 含义一致。
- 请求去重仅共享正在执行的同 key、同结果类型任务；取消后的旧任务不会清除新登记。
- 自定义权限请求器可覆盖内置实现，首次查询不会覆盖宿主注册。
- 默认本地化按资源包匹配当前语言，模板文案位于 Core 的 en/zh-Hans lproj 目录。
- 防抖/节流状态受锁保护；调用方 action 在锁外执行。

## Topics

### 网络协议

- ``CYNetworkClientProtocol``
- ``CYEndpoint``
- ``CYHTTPMethod``
- ``CYAPIResponse``
- ``CYBusinessCodePolicy``
- ``CYNetworkError``
- ``CYAuthenticationPolicy``
- ``CYCredentialInterceptor``
- ``CYCredentialRecovery``
- ``CYRequestInterceptor``
- ``CYResponseInterceptor``
- ``CYRequestDeduplicator``
- ``CYNetworkMonitor``

### 服务

- ``CYAnalyticsService``
- ``CYAnalyticsServiceProtocol``

### 依赖注入

- ``CYFactoryContainer``
- ``CYAppContainer``（Legacy Facade）
- ``NetworkProviding``
- ``CYAppConfig``
- ``CYCoreBootstrap``
- ``DIContainerProtocol``
- ``CYAppEnvironment``

### 管理器

- ``CYToastManager``
- ``CYToastManagerProtocol``
- ``CYLoadingManager``
- ``CYLoadingManagerProtocol``
- ``CYAlertManager``
- ``CYAlertManagerProtocol``

### 缓存

- ``CYCacheManager``
- ``CYCacheSerializer``
- ``CYCacheError``

### 权限

- ``CYPermissionManager``
- ``CYPermissionRequester``
- ``CYPermissionStatus``
- ``CYPermissionType``

### 日志

- ``CYLogger``
- ``CYLogLevel``

### 工具类

- ``CYKeychainHelper``
- ``CYBiometricAuth``
- ``CYFormValidator``
- ``CYAppBadgeManager``
- ``CYDebouncer``
- ``CYThrottler``
- ``CYNetworkMonitor``
- ``CYHapticFeedback``
- ``CYClipboardObserver``
- ``CYDeepLinkHandler``
- ``CYDeviceHelper``

### Mock 测试

- ``MockNetworkClient``
- ``MockAnalyticsService``
- ``MockToastManager``
- ``MockLoadingManager``

### 全局状态

- ``CYAppError``
- ``CYTabID``
- ``CYAppTheme``
- ``CYThemeManaging``
- ``CYThemeManager``
- ``CYAppConstants``
- ``CYSFSymbol``

### 多语言

- ``CYLocalizationManaging``
- ``CYLocalizationManager``
- ``String/cyLocalized``

### Foundation 扩展

- ``Collection`` 扩展（安全索引、去重、分组、分块）
- ``String`` 扩展（验证、本地化、编码、MD5）
- ``Date`` 扩展（格式化、时间戳、相对时间、运算）
- ``Data`` 扩展（Base64、Hex、JSON）
- ``Optional`` 扩展（or、then、orThrow）
- ``Numeric`` 扩展（货币、字节、四舍五入）
- ``Dictionary`` 扩展（合并、QueryString）
- ``Bundle`` 扩展（JSON 解码）
