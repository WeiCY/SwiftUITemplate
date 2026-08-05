import SwiftUI
import CYAppCore
import CYFeedbackStyle

extension CYToastPosition {
    var alignment: Alignment {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }

    func verticalOffset(_ value: CGFloat) -> CGFloat {
        switch self {
        case .top, .center: value
        case .bottom: -value
        }
    }
}

extension CYToastIconColorStrategy {
    func color(for type: CYToastType) -> Color {
        switch self {
        case .typeColor: type.color
        case .fixed(let color): color
        }
    }
}
