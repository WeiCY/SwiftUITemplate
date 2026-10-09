import Foundation

// MARK: - 宿主路由定义
//
// 模板只提供 `CYAppRouter` 机制，具体 Route 由宿主定义。

enum AppRoute: Hashable {
    case articleDetail(Article)
}
