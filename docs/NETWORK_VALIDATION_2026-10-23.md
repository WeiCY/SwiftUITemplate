# 网络增量验证：2026-10-23

本轮基于远端 main `1ca0451`（直接上传与凭证恢复已经存在），分支 `codex/network-reliability-polish`。SolarTerms 锁定的 1.0.1 仅是此前评审对象；没有把旧版问题当作主分支现状，也没有修改 SolarTerms 或其依赖。提交前再次 fetch，确认 main 未前进。没有新增应用依赖或发布 tag。

## 实现

- envelope 先分类 code/message，再严格解码成功模型；业务错误 data 不必匹配成功结构。raw envelope 的严格解码及不恢复语义保持。
- JSON 与 multipart 复用 envelope 解码，204/205 空成功响应一致支持 CYEmptyResponse；direct 空响应保留传输错误。
- 取消恢复等待立即结束该调用方，不重放、不触发该调用方的终态认证失败拦截器；共享恢复继续。发送前后和请求拦截器等待处检查取消。
- Mock 匹配包括分页 query、字典 body、header 和认证策略。复用去重器原有结构化身份编码，摘要规则不变；独立 Encodable body 仍通过记录断言，不增加注册 API。
- 协议注入后的 Mock requestRaw 与具体类型一致；显式注册错误不再被回退掩盖。Mock 与生产端点编码遵循同一策略，并统一抛 encodingFailed。
- CYLoggingInterceptor 正文默认关闭，显式 includeBody: true 保留既有脱敏行为。已同步网络指南、README、架构、变更记录及当前复核入口。

## 实际运行

环境：Debian Linux x86_64，Swift 6.3.3，Alamofire 5.12.0。

```sh
CY_SWIFT=/workspace/.solarterms-env/toolchain-6.3.3/usr/bin/swift python3 scripts/test-network-linux.py
```

**32 个 XCTest、6 个套件通过，0 失败**。包含 20 个新增测试和 12 个已有测试。完整输出见 [运行日志](Validation/network-linux-2026-10-23.log)。日志末尾 Swift Testing 的“0 tests”指该框架未注册测试，不是前面的 XCTest 数量。

覆盖：业务错误与错误 data 形状、凭证过期恢复、原始解码字段路径、raw 不恢复、普通请求/空 multipart 的 204/205、必需数据缺失、传输取消、拦截器期间取消、恢复等待取消、恢复重放上限、Mock 协议注入/分页/body/header/编码失败，以及既有 URL/嵌套 JSON 脱敏。

脚本创建忽略目录 `.build/network-linux`，通过符号链接编译真实生产网络源码，使用真实 Alamofire 与 FoundationNetworking。**边界**：只选取网络相关 Core 源码；测试专用 `os` 锁适配使用 NSLock，OSLog 为无输出适配，本地化返回 key。适配文件位于 `Tests/NetworkHarness`，不进入任何发布 product。不验证 Apple 锁实现、OSLog 输出、本地化资源、DI、CryptoKit 摘要或完整 Core 模块，也不宣称模板支持 Linux。

初次运行旧 `DirectResponseTests.testMultipartDirectResponseRecoversOnceAndHonorsEndpointTimeout` 时，Swift Linux Foundation 的 `InputStream.streamError` 在 Alamofire 文件分片编码中触发 signal 4。Linux 脚本显式打印并排除该一个测试，保留其原始 Apple 测试代码。**空 multipart 的解码测试通过，不代表真实文件分片上传通过。** Linux Foundation 对测试 URLProtocol 的 Sendable 声明有警告，未通过修改业务源码或依赖隐藏。

其他实际检查：

- 修改涉及的 Core / Network 以及网络测试源码通过 Swift frontend 语法检查；不冒充 Apple SDK 类型检查。
- `python3 scripts/verify-component-matrix.py` 通过，71 个公开 UI/support 类型及消费者边界没有回归。
- `git diff --check` 通过；根 Package.swift / Package.resolved 未改。

## 当前环境无法完成

实际尝试根 Package 的 `swift test --filter CYAppNetworkTests`（配置可写 module/cache 路径后），编译在 Linux 缺少 SwiftUI / SwiftData 等 Apple 模块处失败。没有用历史 macOS/iOS 成功记录替代本轮结果。

待 macOS / Xcode 执行：完整 `swift build`、`swift test`、SwiftLint、文档示例类型检查、消费者检查，以及 iOS 宿主构建/测试。真实文件 multipart、下载进度/落盘/取消、系统 URLSession 的全部行为、真实后端契约和凭证轮换仍需对应平台验收。原测试与 CI 步骤保留；本轮未确认远端 CI 结果。

GitHub API 请求返回 Forbidden，不能创建 PR 或查询 Actions。Git HTTPS 拉取可用；交付使用优化分支，不自动合并 main 或发布版本。
