# 网络层重构执行计划（历史归档）

> 本文记录 1.1.0 时的实施过程，部分 Token API 已被后续的
> `CYAuthenticationPolicy` / `CYCredentialRecovery` 取代。当前用法以
> [NETWORK_GUIDE](../NETWORK_GUIDE.md) 为准。

> 状态：**全部完成（Batch 0–16）** — 2026-08-23
> 初始日期：2026-08-22
> 原则：保留现有骨架（`CYEndpoint` / `CYNetworkClientProtocol` / Alamofire / Interceptor / Token 刷新 / DI / Mock），做有限聚焦优化，不重新设计网络框架。

---

## 执行结果总览

| Batch | 目标 | 结果 |
|---|---|---|
| 0 | 影响面扫描固化 + 规范红测试 | ✅ 基线 108 全绿 + 8 条红/占位测试落库 |
| 1 | 取消请求识别（`.cancelled` + ViewModel 忽略） | ✅ 转绿 |
| 2 | 空响应 / 204（`CYEmptyResponse` 真正可用） | ✅ 转绿（含非空类型负向守卫） |
| 3 | `buildURL` 斜杠规范化 | ✅ 3 用例全绿 |
| 4 | multipart 数值参数修复 | ✅ 转绿（Int/Bool/Double/String） |
| 5 | 日志脱敏（Authorization 等） | ✅ 3 测试全绿（纯函数缝隙） |
| 6 | Token 刷新边界（6a 属性 / 6b 递归防护 / 6c requestRaw 语义 / 6d 拦截器时机） | ✅ 4 测试全绿 |
| 7 | `CYResponseStrategy`（envelope/envelopeRaw/direct/empty/data） | ✅ 枚举就绪 |
| 8 | 协议新增 `send` 要求 + 双实现 | ✅ 6 策略测试全绿 |
| 9 | 现有方法路由到 `send`（内部重构） | ✅ 全量回归绿 |
| 10 | `requestVoid` / `requestData` / 泛型 `request(body:)` | ✅ 4 测试全绿 |
| 11 | Mock 完善（`requestRaw` 实现 + 新策略支持） | ✅ 10 测试全绿 |
| 12 | 去重 key 完善（覆盖 Encodable body） | ✅ 2 测试全绿 |
| 13 | multipart 多文件（`CYMultipartPart` + `upload(parts:)`） | ✅ 多 part 测试绿，旧 API 兼容 |
| 14 | 上传/下载进度 + 取消传播 | ✅ 取消 → `.cancelled`；进度回调就绪 |
| 15 | 错误上下文与可观测性 | ✅ 日志含上下文，无回归 |
| 16 | 文档修正 + 最终回归 | ✅ **156/156 全绿** |

**最终测试基线：156 条全部通过（0 失败）。**


---

## 1. 影响面扫描结果（2026-08-22 实测，非假设）

| 扫描项 | 结果 | 对方案的影响 |
|---|---|---|
| `CYNetworkClientProtocol` 实现者 | 仅 2 个：`CYNetworkClient`、`MockNetworkClient` | 协议变更成本低 |
| 协议消费方 | 仅 DI 层（`DIContainerProtocol` / `AppContainer` / `FactoryContainer`） | 协议改动不触碰 DI |
| 生产代码调用点（`request/requestRaw/post/upload/download`） | **0 处**（仅出现在 NetworkClient 自身、Mock、测试、注释） | **无需迁移任何现有业务代码** |
| `CYEndpoint` 生产实现者 | 0 处（仅测试内端点） | 新增 additive 属性零影响 |
| 已确认缺陷 | ① `MockNetworkClient.requestRaw` 直接 `throw unknown`；② `resolveData` 对 `data == nil` 抛 `decodingFailed`；③ 响应拦截器在瞬态 401 时被触发（自动登出提前）；④ multipart 数值参数被 `stringValue` 丢弃；⑤ `download` 用 `withCheckedThrowingContinuation`，取消不传播；⑥ `buildURL` 双斜杠 | 分别对应 Batch 1/2/6/4/14/3 |
| 测试基线 | 既有测试全绿（上一轮核验 108 条） | Batch 0 在此基础上新增红测试 |

---

## 2. 批次划分与验收标准

| Batch | 目标 | 验收标准 | 风险 |
|---|---|---|---|
| 0 | 影响面扫描固化 + 规范红测试 | 基线全绿；6 条运行期红测试明确失败；2 条占位测试已注释说明 | 低 |
| 1 | 取消请求识别（`.cancelled` + ViewModel 忽略） | cancelled 测试转绿；ViewModel 取消不展示错误 | 低 |
| 2 | 空响应 / 204（`CYEmptyResponse` 真正可用） | 空 data 三态 + 204 全绿；非空类型 data==nil 仍抛错 | 低 |
| 3 | `buildURL` 斜杠规范化 | 三种斜杠用例 URL 正确 | 低 |
| 4 | multipart 数值参数修复 | Int/Bool/Double/String 全部写入 multipart | 低 |
| 5 | 日志脱敏（Authorization 等） | 日志不含敏感 Header 值 | 低 |
| 6 | Token 刷新边界（6a 属性 / 6b 递归防护 / 6c requestRaw 语义 / 6d 拦截器时机） | 4 个 commit 各自验收；红测试转绿 | 中 |
| 7 | `CYResponseStrategy`（envelope/envelopeRaw/direct/empty/data） | 枚举就绪、无行为变化 | 低 |
| 8 | 协议新增 `send` 要求 + 双实现（原子批） | 全策略测试绿；旧路径不变 | 中 |
| 9 | 现有方法路由到 `send`（内部重构） | 全部既有测试回归绿 | 中 |
| 10 | `requestVoid` / `requestData` / 泛型 `request(body:)` 扩展 | 新能力测试绿 | 低 |
| 11 | Mock 完善（`requestRaw` 实现 + 新策略支持） | Mock 全 API 可用 | 低 |
| 12 | 去重 key 完善（覆盖 Encodable body） | 去重测试绿 | 低 |
| 13 | multipart 多文件（`CYMultipartPart` + `upload(parts:)`） | 多 part 测试绿；旧 API 兼容 | 中 |
| 14 | 上传/下载进度 + 取消传播 | 进度/取消测试绿 | 中 |
| 15 | 错误上下文与可观测性 | 日志含上下文；无回归 | 低 |
| 16 | 文档修正 + 最终回归 | 全绿；文档与代码一致 | 低 |

---

## 3. Batch 0 红测试清单（`Sources/CYAppNetworkTests/NetworkRegressionTests.swift`）

| 测试 | 对应缺陷 | Batch 0 状态 |
|---|---|---|
| `testEmptyResponseSucceedsWithMissingData` | `data == nil` 被抛 `decodingFailed` | 红（失败） |
| `testEmptyResponseSucceedsWith204NoContent` | 204 空 body 无法解码 | 红（失败） |
| `testURLErrorCancelledIsNotMappedToUnderlying` | 取消被落入 `.underlying` | 红（失败） |
| `testUploadKeepsNumericBodyParameters` | multipart 数值参数被丢弃 | 红（失败） |
| `testLoggingInterceptorRedactsAuthorization` | 日志泄露 Authorization | 占位（注释）：Batch 5 需先引入可测试缝隙 |
| `testRequestRawDoesNotAutoRefreshOnHTTP401` | `requestRaw` 自动刷新语义不一致 | 红（失败） |
| `testResponseInterceptorNotCalledOnTransient401` | 自动登出在瞬态 401 提前触发 | 红（失败） |
| `testAllowsTokenRefreshFalseSkipsRefresh` | 刷新递归风险 | 占位（注释）：Batch 6a 需先新增属性 |

> 占位说明：`CYLoggingInterceptor` 当前把日志直接写入 `os.Logger`，测试无法捕获输出；
> `CYEndpoint` 尚无 `allowsTokenRefresh` 属性，无法在编译期引用。
> 两处均以「现状锁定测试 + 注释中的未来测试」先行落位，待 Batch 5 / 6a 引入缝隙后启用。
> 另外 `testURLErrorCancelledIsNotMappedToUnderlying` 因 `.cancelled` case 尚不存在，
> 以「不得落入 `.underlying`」作为红断言（当前实现正是 `.underlying`，Batch 1 后转绿并可改为精确匹配）。

---

## 4. 执行纪律

每个 Batch 完成后**必须停止**，只允许：

1. 修改该 Batch 范围内的代码
2. 运行对应测试
3. 报告修改内容与测试结果
4. 报告是否存在额外问题

不得自动进入下一个 Batch，必须等待确认。若发现实际代码与方案假设不符，先停止并报告差异。

---

## 5. 明确不做（避免过度设计）

- 破坏性协议收敛（`request/requestRaw/post` 保留为协议要求）
- 自研 URLSession 网络栈 / 移除 Alamofire
- `.string` 响应策略与 `requestString`
- 网络层通用分页模型（分页由业务层负责）
- 全局 Lossy / 万能容错 Codable
- 自动重试机制（第一轮）
- 断点续传 / 分片上传 / 下载管理器
- 离线缓存 / offline-first
- 多 baseURL 动态切换
- 请求 DSL / Builder 模式
- `displayKind` UI 语义迁移
- visionOS / watchOS / macOS 网络层适配
