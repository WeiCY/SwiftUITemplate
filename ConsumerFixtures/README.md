# Public API 消费者验收

这是根 Package 的独立消费者 Package，不是根包测试 target。只使用公开接口、相对依赖 `..`，不依赖 ExampleApp、不复制框架。最低部署 iOS 18 / macOS 15；Swift 6。五个场景各自为独立 target/Product；Proof 可执行入口供链接边界检查，测试 target 聚合场景做行为验收。

| 场景 | 声明根 Product | 运行内容 |
|---|---|---|
| CoreOnly | CYAppCore | 工具/解码，无网络注册 |
| OfflinePersistence | Core + Persistence | 宿主 SwiftData Note、CRUD/错误，原生 @Query/List |
| NetworkOnly | Core + Network | 宿主 Endpoint/模型，URLProtocol 桩；成功、失败、取消 |
| DesignSystemConsumer | DesignSystem | 宿主 Observable、输入/按钮/Card、基础分页；LegacyConsumerPage 编译旧 VM API |
| CustomComposition | Core + UI + DesignSystem | 自定义 Toast/Loading/Alert/ImageLoader、Router；启动第二品牌 |

在仓库根执行（macOS）：

```bash
# 一个新 scratch；只复用已下载的依赖源码，不复用现有编译产物
python3 scripts/verify-consumers.py --cache-from .build --output /tmp/consumer-proof.json
# 不复用源码缓存则省略 --cache-from，需要正常访问 GitHub
# 快速开发时可使用消费者自己的默认 .build
swift test --package-path ConsumerFixtures
# 单产品选择，不要用聚合测试推断按需构建边界
swift build --package-path ConsumerFixtures --product CoreOnlyProof
```

脚本按顺序构建五个 Proof、执行入口、检查编译日志和链接对象列表，再运行行为测试；任何失败均返回非零。输出 JSON 包含实际模块、测试数、Debug 字节和时间。第一项为新 scratch 冷编译，之后的 first 复用此前已经编译的共同依赖；incremental 是同一产品紧接的一次构建。不能把五项均称为完全冷构建，也不是冷网络环境测试。历史实测在 [Evidence/build-proof.json](Evidence/build-proof.json)；CI 生成单独 artifact，不自动覆写仓库记录。

链接模块清单只列模板/第三方 Swift 模块；Core 仍使用 SwiftUI/平台权限等 Apple 系统框架，CoreOnly 不是 Foundation-only。未选择的 Network/Image/Persistence 不参与对应 Proof 的构建和链接；根 Package 的三个第三方包仍参与包级解析。只有有意使用 Factory 注册扩展或高级 Alamofire/Kingfisher 参数才需要接触第三方类型。新 Feature 接收需要的服务，避免整个 DI 容器。

## iOS 独立宿主

打开 `ConsumerFixtures/Host/Consumers.xcodeproj`，选择 Consumers Scheme / iPhone Simulator 运行。宿主只选择消费者 Products，不引用 ExampleApp，所有图片来自注入的本地确定性 GIF Loader，网络行为仅通过本地 URLProtocol 测试。

```bash
xcodebuild -project ConsumerFixtures/Host/Consumers.xcodeproj -scheme Consumers \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/cy-consumer-derived CODE_SIGNING_ALLOWED=NO build
# 把 <SIMULATOR_ID> 换为 xcrun simctl list devices available 的实际设备
xcodebuild -project ConsumerFixtures/Host/Consumers.xcodeproj -scheme Consumers \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' \
  -derivedDataPath /tmp/cy-consumer-derived -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Paging：关闭失败开关后点重试，刷新/追加/重试均由同一个宿主 ConsumerPages 控制；新 renderer 只接快照与操作。失败暂停自动追加。宿主负责页码、并发 guard、请求代次与取消；这里的公开示例给出了这些处理，不把 renderer 当请求框架。分页拥有 List，勿嵌在其他 List/ScrollView。

Custom A/B：各持有自己的 HostComposition。业务和修饰符传相同反馈实例；Router 也分别绑定自己的 NavigationStack。反馈实现仅演示协议替换，不是生产队列/自动消失策略。图片 slow 挂起任务可用 Leave page 验证退出取消。品牌是全进程启动配置，两个 Tab 不是不同品牌窗口。

启动参数 `--large-type` 为 accessibility2；`--large-list` 是 10,000 条本地简单行。UI 测试记录三次列表滚动/页面往返的时间与物理内存；包含自动化等待，不是帧率测量或泄漏证明。最低系统实跑、真机、VoiceOver 和大图性能仍待验收，原始测量在 [ios-ui-measurement.json](Evidence/ios-ui-measurement.json)，详见 [评审矩阵](../docs/MODULE_COMPONENT_REVIEW.md)。

## 第三轮复用专项补充

Offline Tab 是既有 Note 模型的原生编辑 Recipe：先点 Add sample note，再点 Original 打开草稿。取消保留 Original，保存才写入 context；失败保留编辑页并显示错误。输入草稿不直接绑定 @Model，避免取消也修改持久化对象。其跨实体事务和编辑冲突仍由宿主负责。新增 UI 测试覆盖取消和保存，未注入真实磁盘写入失败。

CoreOnly 的 Proof 同时验证负数抽样、非有限字节数和默认 cURL 脱敏，不增加其他 Product。第三轮运行不覆盖 Evidence 中前两轮构建/性能数据；最新验证和截图见 [工程记录](../docs/ENGINEERING_VALIDATION.md#第三轮组件与扩展专项2026-10-19)。
