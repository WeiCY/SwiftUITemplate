import CYAppCore

// MARK: - 宿主 Tab 定义
//
// 模板只提供 `CYTabID` 机制，具体 Tab 由宿主定义。

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case bookmarks
    case settings
    case components

    var id: CYTabID { CYTabID(rawValue: rawValue) }

    var title: String {
        switch self {
        case .home: "home_title".exampleLocalized
        case .bookmarks: "bookmarks_title".exampleLocalized
        case .settings: "settings_title".exampleLocalized
        case .components: "组件 / Components"
        }
    }

    var icon: String {
        switch self {
        case .home: "doc.text"
        case .bookmarks: "bookmark"
        case .settings: "gearshape"
        case .components: "square.grid.2x2"
        }
    }
}
