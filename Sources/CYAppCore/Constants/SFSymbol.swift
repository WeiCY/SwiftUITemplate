import Foundation

/// SF Symbol 快捷常量
///
/// 避免手写字符串出错，提供编译时检查：
/// ```swift
/// Image(systemName: CYSFSymbol.home)
/// Image(systemName: CYSFSymbol.arrow.left)
/// ```
public struct CYSFSymbol {
    private init() {}
    
    // MARK: - 导航
    public struct nav {
        public static let back = "chevron.left"
        public static let forward = "chevron.right"
        public static let up = "chevron.up"
        public static let down = "chevron.down"
        public static let close = "xmark"
        public static let menu = "line.3.horizontal"
        public static let more = "ellipsis"
        public static let moreVertical = "ellipsis.circle"
    }
    
    // MARK: - 常用操作
    public struct action {
        public static let add = "plus"
        public static let remove = "minus"
        public static let delete = "trash"
        public static let edit = "pencil"
        public static let save = "tray.and.arrow.down"
        public static let share = "square.and.arrow.up"
        public static let copy = "doc.on.doc"
        public static let paste = "doc.on.clipboard"
        public static let search = "magnifyingglass"
        public static let filter = "line.3.horizontal.decrease.circle"
        public static let sort = "arrow.up.arrow.down"
        public static let refresh = "arrow.clockwise"
        public static let settings = "gearshape"
        public static let logout = "rectangle.portrait.and.arrow.right"
    }
    
    // MARK: - 状态
    public struct status {
        public static let checkmark = "checkmark"
        public static let checkmarkCircle = "checkmark.circle.fill"
        public static let xmark = "xmark"
        public static let xmarkCircle = "xmark.circle.fill"
        public static let warning = "exclamationmark.triangle.fill"
        public static let info = "info.circle.fill"
        public static let question = "questionmark.circle"
    }
    
    // MARK: - 媒体
    public struct media {
        public static let play = "play.fill"
        public static let pause = "pause.fill"
        public static let stop = "stop.fill"
        public static let next = "forward.fill"
        public static let previous = "backward.fill"
        public static let camera = "camera"
        public static let photo = "photo"
        public static let video = "video"
        public static let mic = "mic"
        public static let speaker = "speaker.wave.2"
    }
    
    // MARK: - 社交
    public struct social {
        public static let heart = "heart"
        public static let heartFilled = "heart.fill"
        public static let star = "star"
        public static let starFilled = "star.fill"
        public static let bookmark = "bookmark"
        public static let bookmarkFilled = "bookmark.fill"
        public static let bell = "bell"
        public static let bellFilled = "bell.fill"
        public static let message = "message"
        public static let messageFilled = "message.fill"
    }
    
    // MARK: - 用户
    public struct user {
        public static let person = "person"
        public static let personFilled = "person.fill"
        public static let personCircle = "person.circle"
        public static let personCircleFilled = "person.circle.fill"
        public static let personAdd = "person.badge.plus"
        public static let people = "person.2"
    }
    
    // MARK: - 位置
    public struct location {
        public static let pin = "mappin"
        public static let pinFilled = "mappin.circle.fill"
        public static let map = "map"
        public static let compass = "location"
        public static let compassFilled = "location.fill"
    }
    
    // MARK: - 标签栏
    public struct tab {
        public static let home = "house"
        public static let homeFilled = "house.fill"
        public static let explore = "safari"
        public static let exploreFilled = "safari.fill"
        public static let profile = "person"
        public static let profileFilled = "person.fill"
        public static let favorites = "heart"
        public static let favoritesFilled = "heart.fill"
        public static let history = "clock"
        public static let historyFilled = "clock.fill"
        public static let notification = "bell"
        public static let notificationFilled = "bell.fill"
    }
}
