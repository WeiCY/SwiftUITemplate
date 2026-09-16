# CYAppCore

纯逻辑层框架，仅依赖 Foundation + FactoryKit。提供协议抽象、工具类、DI 基础设施。

> **按需加载设计**：CYAppCore 不包含网络和图片实现。需要 HTTP 请求请引入 ``CYAppNetwork``，需要远程图片加载请引入 ``CYAppImage``。

## 概述

CYAppCore 是 CYSwiftTemplate 的核心骨架，遵循 **协议驱动 + DI 注入** 的设计原则。
网络实现（Alamofire）和图片加载（Kingfisher）已拆分为独立可选 target：
- ``CYAppNetwork``：`CYNetworkClient` Alamofire 实现
- ``CYAppImage``：`CYKingfisherImageLoader` Kingfisher 实现

### 架构分层

```
CYAppCore (仅 Foundation + FactoryKit)
├── Network      网络协议层（CYEndpoint, CYNetworkClientProtocol, APIResponse）
├── Services     认证 / 分析 / 用户会话
├── DI           依赖注入（Protocol → Factory）
├── Image        图片加载协议（CYImageLoaderProtocol）
├── Cache        Actor 隔离缓存
├── Managers     Toast / Loading / Alert
├── Permissions  权限管理
├── Logger       多级日志
└── Extensions   10 类 Foundation 扩展
```

### 接入示例

```swift
import CYAppCore

// 仅使用协议 + 工具，无需 Alamofire/Kingfisher
let cache = CYCacheManager.shared
let logger = CYLogger.shared
CYToastManager.shared.show("操作成功", type: .success)
```

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

- ``CYAppContainer``
- ``DIContainerProtocol``
- ``CYAppEnvironment``

### 管理器

- ``CYToastManager``
- ``CYToastManagerProtocol``
- ``CYLoadingManager``
- ``CYLoadingManagerProtocol``
- ``CYAlertManager``
- ``CYAlertManagerProtocol``

### 缓存与持久化

- ``CYCacheManager``

### 权限

- ``CYPermissionManager``
- ``CYPermissionProtocol``
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
- ``CYDébouncer``
- ``CYNetworkMonitor``
- ``CYHapticFeedback``
- ``CYClipboardObserver``
- ``CYDeepLinkHandler``
- ``CYDeviceHelper``

### Mock 测试

- ``MockNetworkClient``
- ``MockAuthService``
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
- ``CYStringLocalized``

### Foundation 扩展

- ``Collection`` 扩展（安全索引、去重、分组、分块）
- ``String`` 扩展（验证、本地化、编码、MD5）
- ``Date`` 扩展（格式化、时间戳、相对时间、运算）
- ``Data`` 扩展（Base64、Hex、JSON）
- ``Optional`` 扩展（or、then、orThrow）
- ``Numeric`` 扩展（货币、字节、四舍五入）
- ``Dictionary`` 扩展（合并、QueryString）
- ``Bundle`` 扩展（JSON 解码）
