# 网络框架使用指南（CYAppCore + CYAppNetwork）

> 适用版本：1.2.x（Batch 0–16 网络层升级后，协议收敛为 5 个核心要求）。
> 本文档为网络层**唯一权威使用说明**；`GETTING_STARTED.md` 为整体接入入口，遇到网络细节以此为准。

---

## 1. 核心概念

| 概念 | 说明 |
|---|---|
| `CYEndpoint` | 描述一个 API：路径、方法、头、参数、解码策略与凭证策略 |
| `CYNetworkClientProtocol` | 协议驱动的网络客户端（生产用 `CYNetworkClient`，测试/预览用 `MockNetworkClient`） |
| `CYAPIResponse<T>` | 统一响应包装 `{ code, data, message }` |
| `CYResponseStrategy` | 响应解析策略：envelope / envelopeRaw / direct / empty / data |
| `CYBusinessCodePolicy` | 业务码 ↔ 语义（成功/失败/Token 过期/需重新登录）的可配置策略 |
| `CYRequestInterceptor` / `CYResponseInterceptor` | 请求/响应拦截器（注入 Token、日志、加密、统一登出等） |

请求链路：

```
CYEndpoint → 构建 URLRequest → 请求拦截器（注入 Header/Token）
          → 发送 → 响应拦截器（终态）→ 按策略解码 → 业务码判定 → 结果/错误
```

---

## 2. 快速开始（App 启动时配置）

```swift
import CYAppCore
import CYAppNetwork

@main
struct MyApp: App {
    init() {
        // 1. 网络客户端（静态默认头 + 拦截器）
        CYNetworkConfiguration.configure(
            environment: .production,
            baseURL: "https://api.example.com",
            defaultHeaders: [
                "X-App-Version": "1.2.0",
                "X-Device-ID": UIDevice.current.identifierForVendor?.uuidString ?? "",
            ],
            requestInterceptors: [
                CYCredentialInterceptor(authorizationHeaderProvider: { await accountStore.authorizationHeader }),
                CYLoggingInterceptor(),
            ],
            responseInterceptors: []
        )

        // 2. 业务码策略（按自家后端契约覆盖）
        CYBusinessCodePolicy.configure {
            $0.successCodes      = [0, 200]
            $0.tokenExpiredCodes = [401, 10001, 10002]
            $0.reLoginCodes      = [10003]
            $0.silentCodes       = [90001]
            $0.alertCodes        = [50000]
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```

之后所有页面通过 `CYAppContainer.shared.networkClient` 获取客户端：

```swift
let networkClient = CYAppContainer.shared.networkClient
```

---

## 3. 定义端点（CYEndpoint）

```swift
enum UserEndpoint: CYEndpoint {
    case profile
    case list(page: Int)
    case update
    case login
    case delete(id: Int)

    var path: String {
        switch self {
        case .profile:      return "/api/user/profile"
        case .list:         return "/api/user/list"
        case .update:       return "/api/user/update"
        case .login:        return "/api/auth/login"
        case .delete(let id): return "/api/user/\(id)"
        }
    }

    var method: CYHTTPMethod {
        switch self {
        case .login, .update: return .post
        case .delete:         return .delete
        default:              return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .list(let page):
            return [URLQueryItem(name: "page", value: "\(page)")]
        default: return nil
        }
    }

    // 可选属性（均有默认值，不写也能编译）：
    // var headers: [String: String]?            // 该端点专属请求头
    // var body: CYRequestParams?                // 字典参数（["age": .int(25), "vip": true]）
    // var keyDecodingStrategy / keyEncodingStrategy  // 默认 convertFromSnakeCase / convertToSnakeCase
    var authentication: CYAuthenticationPolicy {
        switch self {
        case .login: return .none
        default:     return .required
        }
    }
}
```

---

## 4. 发起请求（五种 API）

### 4.1 `request` — 自动解包（推荐，99% 场景）

```swift
// 后端返回 {"code":0,"data":{...},"message":"ok"} → 直接得到 User
let user: User = try await networkClient.request(UserEndpoint.profile)
```

业务码非 0 时自动抛 `CYNetworkError`；命中 `tokenExpiredCodes` 自动刷新 + 重放。

### 4.2 `request(_:body:)` — 带 Encodable body（等价旧 `post`）

```swift
struct LoginBody: Encodable, Sendable { let username: String; let password: String }

let user: User = try await networkClient.request(UserEndpoint.login, body: LoginBody(...))
```

### 4.3 `requestRaw` — 返回完整 envelope（手动处理业务码）

```swift
let response: CYAPIResponse<User> = try await networkClient.requestRaw(UserEndpoint.profile)
switch response.businessResult {
case .success:            handle(response.data)
case .tokenExpired:       refreshUI()      // 框架已自动刷新
case .businessError(_, let message, let display):
    display == .alert ? showAlert(message) : toast(message)
case .needReLogin:        gotoLogin()
}
```

> ⚠️ raw 语义：收到 HTTP 401 **不会**触发自动刷新 + 重放，直接抛 `httpError(401)`。

### 4.4 `requestVoid` — 只确认成功

```swift
// 适合 DELETE / 只返回 code+message 的接口；业务错误照常抛出
try await networkClient.requestVoid(UserEndpoint.delete(id: 123))
```

### 4.5 `requestData` — 原始 Data

```swift
let imageData: Data = try await networkClient.requestData(ImageEndpoint.fetch)
```

> ⚠️ raw 语义：`requestData` 返回原始二进制，不参与 envelope 业务码判定，**不触发凭证恢复与重放，也不参与请求去重**。若下载资源需要携带最新凭证，请自行确保凭证有效。

---

## 5. send + 响应策略（底层统一入口）

`request` / `requestRaw` / `requestVoid` 全部是 `send` 的便捷封装；需要非标准响应形态时直接用 `send`：

```swift
// .envelope：自动解包 data（等价 request）
let user: User = try await networkClient.send(UserEndpoint.profile, strategy: .envelope)

// .envelopeRaw：返回原始 envelope（等价 requestRaw，T = CYAPIResponse<X>）
let response: CYAPIResponse<User> = try await networkClient.send(UserEndpoint.profile, strategy: .envelopeRaw)

// .direct：响应体直接就是 T（无 envelope，适合第三方/OpenAPI）
let status: ThirdPartyStatus = try await networkClient.send(OpenAPI.status, strategy: .direct)

// .empty：显式空响应策略（204/205），仅 CYEmptyResponse 可用
// 注意：requestVoid 实际走的是 .envelope + CYEmptyResponse，而非 .empty
let _: CYEmptyResponse = try await networkClient.send(UserEndpoint.delete, strategy: .empty)

// .data：请使用 requestData（send 会明确抛错提示）
```

策略矩阵：

| 策略 | 解码方式 | 业务码抛错 | 401 自动刷新 |
|---|---|---|---|
| `.envelope` | `CYAPIResponse<T>` 解包 | ✅ | ✅ |
| `.envelopeRaw` | 直接解码 T（T=envelope） | ❌ | ❌ |
| `.direct` | 直接解码 T | ❌ | ❌ |
| `.empty` | 空响应 → `CYEmptyResponse` | ❌ | ❌ |
| `.data` | 由 `requestData` 提供 | — | — |

---

## 6. 自定义业务码（成功 / 失败 / 特殊错误码）

框架不硬编码 `code == 0`，全部由 `CYBusinessCodePolicy` 判定，App 启动时按项目定制：

```swift
CYBusinessCodePolicy.configure { policy in
    policy.successCodes      = [0, 200]              // 成功
    policy.tokenExpiredCodes = [401, 10001, 10002]   // 特殊码 → 自动刷新 + 重放
    policy.reLoginCodes      = [10003]               // 需重新登录
    policy.silentCodes       = [90001]               // 静默（不打扰用户）
    policy.alertCodes        = [50000]               // 弹窗强提示
    // 其余未列出的码 → businessError（默认 Toast 展示）
}
```

- `code` 命中成功集 → 正常返回 `data`
- 命中 `tokenExpiredCodes` → 抛 `tokenExpired`，与 HTTP 401 同链路自动刷新重放
- 命中 `reLoginCodes` → 抛 `needReLogin`
- 其余 → 抛 `businessError(code:message:)`，`CYNetworkError.displayKind` 给出建议展示方式

测试中恢复默认：`CYBusinessCodePolicy.reset()`。

---

## 7. 默认请求头 / Token / 自定义拦截器

三种注入层级（优先级从低到高，后写覆盖先写）：

```swift
// ① 静态默认头（全请求生效）
CYNetworkConfiguration.configure(
    baseURL: "...",
    defaultHeaders: ["X-App-Version": "1.2.0", "X-Lang": "zh"]
)

// ② 端点专属头（只对该端点生效）
var headers: [String: String]? { ["X-Scene": "profile"] }

// ③ 拦截器（动态值，如每次变的 token / 时间戳 / 签名）
struct SignatureInterceptor: CYRequestInterceptor {
    func intercept(_ request: inout URLRequest) async {
        request.setValue(sign(), forHTTPHeaderField: "X-Sign")
    }
}
```

**凭证注入**使用 `CYCredentialInterceptor`，完整 Header 值由宿主决定：

```swift
CYCredentialInterceptor { await accountStore.authorizationHeader }
```

凭证恢复重放后，请求拦截器会重新执行并读取最新值。

---

## 8. 上传（单文件 / 多文件 / 进度 / 大小限制）

```swift
// 单文件
let avatar: Avatar = try await networkClient.upload(
    UserEndpoint.uploadAvatar,
    parts: [CYMultipartPart(data: imageData, mimeType: "image/jpeg", fileName: "a.jpg", paramName: "file")],
    additionalParams: ["user_id": "123"]
)

// 多文件 + 进度
let result: UploadResult = try await networkClient.upload(
    UserEndpoint.uploadAttachments,
    parts: [
        CYMultipartPart(data: imageData, mimeType: "image/jpeg", fileName: "a.jpg", paramName: "avatar"),
        CYMultipartPart(data: coverData, mimeType: "image/png", fileName: "c.png", paramName: "cover"),
    ],
    additionalParams: ["scene": "profile"],
    progress: { fraction in progressView.value = fraction }   // fraction ∈ [0, 1]
)
```

- `endpoint.body` 的字典参数也会写入 multipart（Int/Bool/Double 自动转文本）
- 超过 `CYAppConstants.maxUploadSizeMB` 会在发请求前抛 `CYNetworkError.payloadTooLarge`

---

## 9. 下载（进度 / 取消传播）

```swift
let fileURL = try await networkClient.download(
    FileEndpoint.downloadPDF(id: "doc123"),
    to: documentsDirectory.appendingPathComponent("doc.pdf"),
    progress: { fraction in progressView.value = fraction }
)

// 取消：Task.cancel() 会取消底层请求，错误映射为 CYNetworkError.cancelled
let task = Task { try await networkClient.download(...) }
task.cancel()
```

---

## 10. 凭证恢复边界

- 仅 `.required` 端点在 HTTP 401 或业务码命中 `tokenExpiredCodes` 时触发恢复 + 重放
- **最多重放一次**：重放仍 401 或恢复失败时直接抛错
- `.none` 与 `.optional` 端点不触发凭证恢复
- **`requestRaw` / `direct` / `empty` / `requestData`** → raw 语义，401 不触发刷新
- 恢复动作由宿主通过 `CYCredentialRecovery` 提供，不绑定具体 Token 模型

---

## 11. 请求去重

```swift
let deduplicator = CYAppContainer.shared.requestDeduplicator

// GET：相同 key 的并发请求只执行一次
let user: User = try await networkClient.requestWithDeduplication(
    UserEndpoint.profile, deduplicator: deduplicator
)

// POST：Encodable body 自动纳入去重键（相同 body 合并，不同 body 不误合并）
let updated: User = try await networkClient.requestWithDeduplication(
    UserEndpoint.update, body: UpdateBody(...), deduplicator: deduplicator
)
```

去重键默认 = `method:path:query:body字典哈希`；`CYRequestDeduplicator.cancel(key:)` / `cancelAll()` 可手动取消。

---

## 12. 日志（自动脱敏）

`CYLoggingInterceptor` 自动脱敏，无需配置：

| 类型 | 脱敏内容 |
|---|---|
| 请求头 | `Authorization` / `Proxy-Authorization` / `Cookie` / `X-Api-Key` / `Token` 等 → `***` |
| 请求/响应体 | `password` / `token` / `access_token` / `refresh_token` / `secret` / `api_key` 等字段 → `***` |

```swift
CYLoggingInterceptor()                      // 打印请求 + 响应 Body
CYLoggingInterceptor(includeBody: false)    // 只打印请求行与 Header
```

错误日志自动带上下文：`[GET /api/user/profile] HTTP 500 | <错误描述>`。

---

## 13. 错误处理（CYNetworkError）

| case | 场景 | 建议处理 |
|---|---|---|
| `.cancelled` | Task/URLSession 取消 | 静默（`CYBaseViewModel.executeTask` 自动忽略） |
| `.timeout` | 请求超时 | Toast「请求超时」 |
| `.noConnection` | 断网/网络丢失 | Toast「无网络」+ 引导检查网络 |
| `.httpError(statusCode:data:)` | HTTP 非 2xx | 按状态码处理（401 已由框架刷新链路接管） |
| `.businessError(code:message:)` | 业务失败 | 按 `displayKind` 展示 |
| `.tokenExpired` | 命中 tokenExpiredCodes | 框架自动刷新重放；UI 补充提示 |
| `.needReLogin` | 需重新登录 | 跳登录页 |
| `.decodingFailed` / `.encodingFailed` | JSON 编解码失败 | 日志 + 兜底提示 |
| `.payloadTooLarge(limitMB:)` | 超过上传上限 | 提示压缩/分片 |
| `.underlying` | Alamofire/URLSession 原始错误 | 兜底 |

ViewModel 层用 `CYBaseViewModel.executeTask` 自动管理 loading / error / retry，取消错误不会污染 UI：

```swift
await executeTask { [weak self] in
    self?.user = try await networkClient.request(UserEndpoint.profile)
}
```

---

## 14. 空响应 / 204

```swift
let _: CYEmptyResponse = try await networkClient.request(UserEndpoint.delete(id: 123))
```

以下三种后端返回对 `CYEmptyResponse` 均为成功：204 空 body、`{"code":0,"message":"ok"}`（缺 data 键）、`data: null`。
非空类型遇到 data 缺失仍会抛 `decodingFailed`（不静默吞错）。

---

## 15. Mock（测试 / SwiftUI Preview）

```swift
let mock = MockNetworkClient()
mock.registerResponse(User(id: 1, name: "Test"))          // 按类型注册
mock.registerResponse(User(id: 2, name: "B"), for: UserEndpoint.profile)  // 按端点注册
mock.registerError(for: User.self, CYNetworkError.timeout) // 注册错误
mock.shouldFail = true                                     // 全局失败

let user: User = try await mock.request(UserEndpoint.profile)          // 走 send(.envelope)
let raw: CYAPIResponse<User> = try await mock.requestRaw(UserEndpoint.profile)  // 注册普通值自动包 envelope
let data: Data = try await mock.requestData(ImageEndpoint.fetch)       // 注册 Data
```

Mock 只需实现 `send`×2 / `requestData` / `upload` / `download` 五个核心方法，其余 API 由协议扩展自动提供。

### 断言请求参数

`MockNetworkClient` 会记录收到的每个请求，可在测试中断言方法、路径、Body 与上传分片：

```swift
_ = try await mock.request(UserEndpoint.update, body: UpdateBody(name: "new"))
let record = mock.recordedRequests.last
let body = record?.body                        // Encodable body 或 endpoint.body 字典的 JSON
try JSONDecoder().decode(UpdateBody.self, from: body!)  // 断言实际发送内容

mock.clearRecordedRequests()                   // 清空记录（保留已注册响应）
```

记录包含失败的调用（`shouldFail` 或注册错误），便于验证「请求已发出但失败」。

---

## 16. 行为变更提醒（相对 1.0.0）

1. **`requestRaw` 收到 HTTP 401 不再自动刷新重放**，直接抛 `httpError(401)`（完全 raw 语义）。
2. **响应拦截器只收到终态响应**：瞬态 401（刷新成功后重放的中间态）不会触发自动登出等逻辑。
3. **`post` / `CYUploadConfig` 已删除**：改用 `request(_:body:)` / `upload(parts:)`。
4. **协议收敛为 5 个核心要求**：`send`×2、`requestData`、`upload(parts:progress:)`、`download(progress:)`，其余为协议扩展。
