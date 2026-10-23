# 当前工程复核

2026-10-23 网络增量修复与本轮验证边界见 [网络验证记录](NETWORK_VALIDATION_2026-10-23.md)。下方 Apple 平台结果均为历史记录，未用来代替本轮验证。

## 最终收尾补充（2026-10-19）

当前公开API以[第四轮评审与迁移清单](MODULE_COMPONENT_REVIEW.md)和[接入指南](GETTING_STARTED.md)为准。模块边界与独立消费者成果保留；重复布局/导航/键盘与同义接口已删除，OTP和显式Codable偏好已迁移，没有为本轮删除项保留兼容壳。源码、资源、测试、两个宿主和必要截图一起纳入本地基线。

第四轮本机结果为macOS235个测试、消费者7个行为测试、iOS ExampleApp49个原生回归与8个UI通过；独立宿主和小屏按工程记录所述分批验证。最终收尾仅改文档，未把前轮结果描述为重新全量运行，也未推送触发远端CI。真机短信自动填充、VoiceOver、iPad分屏/浮动键盘和真实业务契约仍待按场景验收，详见[验证记录](ENGINEERING_VALIDATION.md)。

以下2026-10-18正文与“第二轮交付”保留为历史快照；当时的公开类型数量和兼容决策不代表第四轮后的公开面。

复核日期：2026-10-18。适用于主干 Unreleased；历史评测见 archive。本文记录代码和验证依据，不通过修改评分替代实现。

## 当前结论

第二轮独立接入与组件矩阵见 [MODULE_COMPONENT_REVIEW](MODULE_COMPONENT_REVIEW.md)，其证据补充下表，保留上轮稳定性成果。

7 个 Library 依赖边界保持稳定。Network / Image / Persistence 可选，业务模型、路由和 Schema 归宿主。本轮补齐此前运行行为和宿主接入上的缺口；具体执行结果和工具链输出见 [ENGINEERING_VALIDATION](ENGINEERING_VALIDATION.md)。

| 领域 | 实施结果 | 依据 |
|---|---|---|
| UI 隔离 | 主题应用、设备 idiom、触觉方法显式 MainActor | iOS Package / App 编译；没有用 unchecked 或 unsafe 绕过 UIKit 警告 |
| 分页 | 首次/刷新/追加失败分别展示，显式重试同页，空态可刷新 | PaginationRecovery、既有代次竞争回归及搜索组合测试 |
| 持久化 | 可抛错创建、宿主错误页/重试、接收配置与迁移计划 | 原始错误捕获、磁盘 V1→V2 数据保留、CRUD 和宿主恢复 UI 测试 |
| 图片 | 取消传递、一次恢复、网络返回原始字节 | 取消竞争状态机测试、Kingfisher URLProtocol 集成、URL 替换和恢复测试 |
| 日志 | query/Header/结构化 JSON 统一脱敏，未知 Body 隐藏 | 嵌套数组、大小写、转义引号和损坏 JSON 回归 |
| DI / 反馈 | Feature 注入，挂载同实例，Alert 支持存在类型 | Factory 快照恢复、注入测试、自定义 Toast/Loading/Alert 模拟器 UI 测试 |
| 接入与组件 | 本地 Package Xcode 宿主、组件目录、三种组合示例 | App 构建、原生回归与 UI 测试；最短步骤见 README |
| 品牌与扩展 | 单一启动 Token、Dynamic Type、工具边界与动画取消 | Token/日期/字符串/解码/取消测试；默认与第二品牌示例 |

## 已明确保留的限制

- 品牌配置只保证启动时使用，尚无运行时品牌刷新保证。
- 页码分页根据条数推导 hasMore，不新增游标或服务端快照框架。
- 图片 Data 协议仍有视图解码，Kingfisher 缓存命中可能重新序列化；测量不能外推到 iOS 整体性能。
- 日志规则依赖字段名，无法猜测未知普通字段和路径里的秘密；宿主日志同样需要约束。
- 旧持久化 init 仍 fail-fast，迁移到抛错工厂才有恢复机会。
- 系统 PhotosPicker 取消不会产生选择结果，但未承诺系统取消回调；网格/相机取消和系统导入失败有显式入口。
- withTimeout 无法强行终止不配合取消的操作。

## 仍未完成的运行验收

真机触觉、实际相册/相机交互、真实视频源、完整 VoiceOver/最大字号/后台生命周期矩阵、生产数据库副本迁移、真实后端和 TestFlight 流程仍需要宿主验收。模拟器 UI 测试和单元测试不替代这些结果。

后续任务见 [ROADMAP](ROADMAP.md)，公共 API 迁移见 [CHANGELOG](../CHANGELOG.md)。

## 第二轮交付

五个 public-only 消费者与链接检查已接入 CI。分页新增宿主快照展示，旧 VM API 保留；Network 增加 Foundation 配置重载。七个模块、76 个公开 UI/支撑类型及扩展均有能力与未验收项记录。目录增加搜索索引/组合，UI 测试图片使用本地 Loader。没有因单例、继承、AnyView 或依赖箭头进行额外拆库。

本轮未发现仍阻塞一般接入的已确认 P1。启动全局配置、包级依赖解析、具体工具类型和平台系统服务边界保留；最低系统实跑/真实媒体/VoiceOver/iOS 大图性能未验收，不能以当前系统通过外推。
