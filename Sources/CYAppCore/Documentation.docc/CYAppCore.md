# CYAppCore

纯逻辑层框架，无 SwiftUI 依赖。提供网络请求、缓存、DI、权限管理、日志等基础设施能力。

## 概述

CYAppCore 是 CYSwiftTemplate 的核心模块，遵循 **协议驱动 + DI 注入** 的设计原则。所有主要组件均通过协议暴露，消费项目可通过 Factory DI 容器替换任意实现。

### 架构分层

```
CYAppCore (Layer 0)
├── Network     网络层（Alamofire 桥接）
├── Services    认证 / 分析 / 用户会话
├── Cache       内存 + 磁盘缓存（Actor 隔离）
├── DI          依赖注入（Protocol → Facade → Factory）
├── Managers    Toast / Loading / Alert 管理器
├── Permissions 相机 / 相册 / 定位 / 通知
├── Logger      多级结构化日志
├── Helpers     工具类（Keychain / 生物识别 / 表单验证等）
└── Extensions  10 类 Foundation 扩展
```

### 核心能力

| 模块 | 职责 | 关键类型 |
|------|------|---------|
| Network | RESTful API 请求、业务码处理、Token 刷新、请求去重 | ``CYNetworkClient``, ``CYAPIResponse``, ``CYNetworkError`` |
| Services | 认证流程、用户会话管理、分析上报 | ``CYAuthService``, ``CYUserSession``, ``CYAnalyticsService`` |
| Cache | 内存 + 磁盘缓存，支持 TTL 和命名空间 | ``CYCacheManager`` |
| DI | 协议驱动的依赖注入（Protocol → Facade → Factory） | ``CYAppContainer``, ``DIContainerProtocol`` |
| Managers | Toast / Loading / Alert 全局管理器 | ``CYToastManager``, ``CYLoadingManager``, ``CYAlertManager`` |
| Permissions | 统一权限请求（相机、相册、定位、通知） | ``CYPermissionManager`` |

### 接入示例

```swift
import CYAppCore

@main
struct MyApp: App {
    init() {
        CYAppConfiguration.configure(
            environment: .production,
            baseURL: "https://api.example.com"
        )
        CYBusinessCodePolicy.configure {
            $0.successCodes = [0, 200]
        }
    }
}
```

## Topics

### 网络请求

- ``CYNetworkClient``
- ``CYNetworkClientProtocol``
- ``CYEndpoint``
- ``CYHTTPMethod``
- ``CYAPIResponse``
- ``CYBusinessCodePolicy``
- ``CYNetworkError``
- ``CYRequestInterceptor``
- ``CYResponseInterceptor``
- ``CYRequestDeduplicator``
- ``CYNetworkMonitor``

### 服务

- ``CYAuthService``
- ``AuthServiceProtocol``
- ``CYUserSession``
- ``UserSessionProtocol``
- ``CYAnalyticsService``
- ``CYAnalyticsServiceProtocol``
- ``TokenPair``
- ``User``
- ``UserRole``

### 依赖注入

- ``CYAppContainer``
- ``DIContainerProtocol``
- ``CYAppConfiguration``
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
- ``CYAppTab``
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
