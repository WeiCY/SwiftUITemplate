import CYAppCore

// MARK: - 宿主 Tab 定义
//
// 模板只提供 `CYTabID` 机制，具体 Tab 由宿主定义。

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case bookmarks
    case settings

    var id: CYTabID { CYTabID(rawValue: rawValue) }

    var title: String {
        switch self {
        case .home: "文章"
        case .bookmarks: "收藏"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: "doc.text"
        case .bookmarks: "bookmark"
        case .settings: "gearshape"
        }
    }
}
