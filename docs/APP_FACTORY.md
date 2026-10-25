# 独立 App 工厂：评审与使用

评审日期：2026-10-25。目标是批量创建独立 App、统一架构和工程规范。
本轮基于当前源码、Package、ExampleApp、ConsumerFixtures、CI 与接入文档检查；没有重跑历史 macOS/iOS 测试。

## 结论

现有项目已经是一个有较完整测试与示例的模块化 SwiftUI 基础库，但原来的创建路径主要是手工添加 Product 或复制示例。
工厂化最优先的工作是把“创建、配置、验收、升级”变成稳定流程。继续增加组件或重写 DI 的收益较低。

建议维持两部分：公共能力通过 Swift Package 版本升级；宿主通过生成器一次性创建，独立拥有业务代码。
ExampleApp 保留为功能展示和集成参考，生成的新 App 使用单独的最小骨架。

## 全局评审

| 领域 | 代码现状与判断 | 优化优先级 |
|---|---|---|
| 技术基础 | Swift 6、iOS 18/macOS 15、Observation、actor/MainActor 已具备；无需为现代化更换框架 | 保持；最低 OS 由产品覆盖率决定 |
| 模块边界 | 七个 Product，业务 Route/Schema/账号留宿主，独立消费者检查已存在 | 保持当前分层 |
| 创建流程 | 原接入指南要求手工建 target 或参考 ExampleApp，缺少独立最小产物 | P0，本轮补生成器 |
| 配置隔离 | Core 有 development/production，但新宿主没有统一构建配置 | P0，本轮生成 xcconfig 与不同 Bundle ID；有真实测试环境时再加 Staging |
| 依赖注入 | Feature 已可初始化注入；Factory 与 Legacy Facade 仍包含全局解析 | P1，新骨架从组合根显式传依赖；逐步减少业务中的 shared，不引入新 DI 框架 |
| 依赖成本 | Product 可选不等于包依赖无需解析，根 Package 声明了 Alamofire/Kingfisher/Factory | P1，测量真实初始化耗时；若离线 App 被依赖解析拖累，再拆独立适配包 |
| 发布与升级 | 主干文档含破坏性 API 清理，不能假设主干与已发布 tag 相同 | P0，选定可访问的不可变 revision；发布兼容版本与迁移指南后再批量升级 |
| 隐私资源 | 当前包未发现 PrivacyInfo.xcprivacy；Core 使用 UserDefaults、systemUptime 等 API | P0，正式发布前逐项核对 Required Reason API，补包级清单并验证归档；新骨架仅声明初始偏好使用 |
| 工程验证 | 已有 Package、消费者、ExampleApp CI；缺生成产物回归 | P0，本轮增加生成器测试和生成宿主 CI；macOS 任务仍待执行 |
| 可复现构建 | Package.resolved 已存在；CI 选 runner 默认 Xcode，部分工具由 Homebrew 安装 | P1，统一固定 Xcode/XcodeGen/SwiftLint 版本；生成产物保存模板来源并恢复传递依赖锁 |
| 产品发布 | 示例不等同于真实后端、真机、签名、TestFlight 验收 | P1，先用一个真实 App 打通，再固化签名与发布自动化 |
| 文档维护 | REVIEW/ROADMAP 混合多轮历史收尾记录，容易误判当前状态 | P2，稳定后归档历史，入口只保留当前规则、用法和已知限制 |

P0 是工厂正式投入批量使用前的优先工作，并不表示本轮全部完成。

## 本轮落地范围

- `scripts/create-app.py`：Python 标准库，无网络访问，不执行外部命令。
- `templates/minimal`：App/Bootstrap/Config/Dependencies + 单个 Home Feature + 启动/反馈 UI 测试。
- XcodeGen 的 `project.json` 是工程配置来源；支持 iPhone/iPad，Swift 6、iOS 18。
- 默认四个基础 Product；不引入示例 Article/Bookmark、网络/Kingfisher/SwiftData Product 或业务 Tab。
- Debug/Release 分离 Bundle ID 与显示名，Feature 和 UI 使用同一反馈实例。
- 远端依赖要求完整 commit SHA；manifest 记录来源、Product、骨架版本，生成结果不含时间戳。
- 已有输出目录（包括空目录和符号链接）拒绝覆盖；输入校验失败不创建项目。
- 生成的 `ci.sh` 包含 lint、Debug/Release 构建和启动/反馈 UI 测试；仓库增加对应工厂 CI。

这次没有修改现有公共 Swift API。生成器仅提供最小 iOS 骨架，macOS 宿主、网络/离线存储预设、自动升级业务源码不在已实现范围。

## 创建项目

开发时先以本地模板验证：

```bash
python3 scripts/create-app.py --name MyApp --bundle-id com.example.myapp \
  --template-path "$PWD" --output ../MyApp
cd ../MyApp
brew install xcodegen swiftlint
xcodegen generate --spec project.json
open MyApp.xcodeproj
bash ci.sh
```

正式独立仓库用远端版本。把下面的 `<published-40-character-commit-sha>` 换为已经推送、可访问且已验收的模板提交：

```bash
python3 scripts/create-app.py --name MyApp --bundle-id com.example.myapp \
  --template-revision '<published-40-character-commit-sha>' --output ../MyApp
```

生成器不联网核验 SHA 是否存在；首次 SPM 解析会验证。未发布的本地提交不能当作远端可用版本。
本地 path 模式用于开发，包含机器绝对路径，不适合作为团队正式依赖。

首次 `bash ci.sh` 将解析锁保存为项目根目录 `Package.resolved`，应与 `project.json`、manifest 一起提交。
重生成工程时 CI 会恢复锁文件并严格解析。修改依赖版本时，删除旧锁、重新解析、评审差异后提交新锁。
App Icon、品牌、本地化、签名和发布元数据由宿主补充；不默认添加相机、相册等权限。
隐私清单只是初始偏好存储声明，不覆盖后续 SDK、所有框架 API 或产品数据收集行为。

## 建议后续顺序与验收

1. 在 macOS 执行生成宿主 CI，确认 Debug/Release 与启动/反馈测试通过，再修复发现的问题。
2. 核对模板及第三方的隐私 API 清单，用真实归档检查资源与声明；发布经验证的模板版本。
3. 用一个独立 App 验证真实 Feature、签名、TestFlight，记录建项目与升级耗时。
4. 真实需求重复后再补 network / persistence 预设，每种预设必须有独立生成与构建测试。
5. 固定工具链，建立各 App 的模板版本清单；升级用 PR 修改依赖并跑宿主测试，不重新覆盖宿主源码。

本轮本地验证：6 项生成器测试通过；既有 71 个公开 UI/支撑类型矩阵检查通过。
当前 Linux 环境无 Swift/Xcode/XcodeGen，未验证 XcodeGen 实际生成、Swift 编译、模拟器 UI 或远端 CI；新增 CI 配置不是通过证据。
