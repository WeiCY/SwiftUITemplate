import CYAppCore

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case explore
    case profile

    var id: CYTabID { CYTabID(rawValue: rawValue) }

    var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .explore: "safari"
        case .profile: "person"
        }
    }
}
