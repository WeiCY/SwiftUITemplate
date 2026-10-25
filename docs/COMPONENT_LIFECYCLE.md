# 组件、媒体和缓存增量优化（2026-10-25）

本轮完成上次复核的三个中优先级方向；与前两轮未提交的 Core/平台修复一起交付。
未升级第三方库，未增加 Library，也没有修改业务宿主的数据模型。

## 动画生命周期

- Shimmer 使用条件子树内的 PhaseAnimator，关闭再开启时重新开始；overlay 不接收点击、不重复暴露无障碍内容。
- Loading 的循环动画 State 移到独立子视图。开启 Reduce Motion 或 Scene 非 active 时移除动画子树，改用静态装饰圆，恢复后重新创建。
- Shimmer 同样响应 Reduce Motion 和 Scene 状态；Skeleton 的负数行/卡片数量按零处理，行高和宽度比例处理 NaN/Infinity/越界。

系统 ProgressView 仍由系统负责动画；这里停用的是模板额外的脉冲与闪烁。运行中更换任意自定义 pulseAnimation 的刷新不在本轮保证范围。

## 布局和无障碍

- FlowLayout 将无限/未指定宽度视为内容固有宽度，不向父布局返回无限宽；测量与放置使用同一宽度提议，长文本可以换行。
- 流式布局从语义 leading 开始，RTL 从右向左；负数/非有限间距归零。要求子组件本身接受宽度约束，fixedSize 的不可压缩内容仍可超宽。
- Onboarding 普通尺寸保留原生分页，每页内容可滚动；辅助功能字号或高度小于 400 时使用完整滚动页面和上/下一页按钮。
- 完成/下一页复用 PrimaryButton 的 minHeight 和 onPrimary 品牌色；页码有无障碍名称，标题有 header trait，装饰图标隐藏。
- 增加中文/英文“页码”“上一页”资源，页面数量变化时限制当前索引。Reduce Motion 下不添加页面切换动画。

## 媒体

系统 PhotosPicker **此前已有 onImportFailure 聚合回调**，本轮在其基础上增加 `onItemImportFailure(index, error)`，给出选择数组中从零开始的索引和原始错误。
成功项继续交给 onPicked，失败项逐个报告后调用原聚合回调；任务取消时不提交过期结果。grid 仍以 PHAsset 引用交给宿主，新增导入回调只适用于 system 的实际 Transferable 导入。

`CYMediaItem.loadVideoData(maximumBytes:)` 按块读取文件，默认最多 32 MiB，保留临时文件所有者直到读取结束；逐块检查取消和容量，防止文件读入过程中增长越界。
旧 loadData 读取文件视频时使用该默认限制，超限/失败返回 nil；需要区分原因请使用新的 throws 方法。
**这是行为收紧**：此前 loadData 会尝试整块读取任意大的视频。

大视频直接使用 item.videoURL + 文件上传接口（如宿主的 URLSession 文件上传），并持有 item 直至上传完成；不要为大文件不断提高 Data 上限。
当前 CYAppNetwork 的 multipart part 仍是 Data，不能把文件 URL 直接传入；本轮没有重写网络上传 API。
网格 PHAsset 视频需要宿主用 Photos 导出文件；loadData 不再把视频当图片请求。图片解码的大图峰值仍需 downsampling/真机测量，不宣称所有媒体内存问题已解决。

## 缓存

- 删除 NSCache 之外的无界 memoryKeyIndex；内存缓存默认软限制 32 MiB、256 项，非正 memoryByteLimit 禁用内存缓存。
- 清理指定命名空间时丢弃本实例全部内存缓存，其他命名空间磁盘值保留并可重新读取。
- 新增 `await cache.trimDisk(to: bytes)`，默认预算 128 MiB：只处理 v2 内摘要命名的缓存文件，按最后写入时间淘汰到预算内；跳过符号链接和无关文件。
- 清理前使内存失效，避免已从磁盘淘汰的值仍由内存返回。清理失败通过已有 Result 报告。

该接口是显式维护，建议启动/进入后台或批量写入后调用；避免每次 save 扫描整个磁盘目录。
后续写入可再次超过预算，NSCache 上限是软上限；不提供跨进程全局配额、自动定时清理或永久存储保证。

```swift
// compile-check: cache-maintenance
import CYAppCore

func maintainCache() async throws {
    let cache = CYCacheManager(memoryByteLimit: 16 * 1_024 * 1_024)
    let result = await cache.trimDisk(to: 64 * 1_024 * 1_024)
    try result.get()
}
```

## 验证与未验收项

本轮新增 8 项 Swift 回归：Flow 几何 3 项、缓存淘汰/禁用内存 3 项、视频大小/取消 2 项。
前两轮新增 14 项，因此本次合计新增 22 项 Swift 测试；**当前无 Swift/Xcode，均未执行，不能当作通过证据**。
Python 生成器 6 项、71 个公开 UI/支撑类型矩阵、隐私 plist 结构与 git diff 检查通过。

macOS 执行完整 swift test、strict SwiftLint、文档编译和 iOS UI 测试；真机验证动画开关/后台恢复、最大字号/RTL/VoiceOver、Photos 成功/部分失败/取消及大视频上传。
纯几何测试不能代替 RTL 实际放置与屏幕阅读器验收。新增文件是否进入 Xcode 宿主测试目标也需核对；SPM 测试按目录自动收录。
