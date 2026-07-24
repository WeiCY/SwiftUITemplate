import SwiftUI
import CYAppCore
import CYFeedbackStyle

// MARK: - CYAppUI 源兼容导出

public typealias CYToastPosition = CYFeedbackStyle.CYToastPosition
public typealias CYToastIconColorStrategy = CYFeedbackStyle.CYToastIconColorStrategy
public typealias CYFeedbackShadow = CYFeedbackStyle.CYFeedbackShadow
public typealias CYToastStyle = CYFeedbackStyle.CYToastStyle
public typealias CYLoadingIndicatorStyle = CYFeedbackStyle.CYLoadingIndicatorStyle
public typealias CYLoadingCardStyle = CYFeedbackStyle.CYLoadingCardStyle
public typealias CYLoadingStyle = CYFeedbackStyle.CYLoadingStyle
public typealias CYFeedbackConfiguration = CYFeedbackStyle.CYFeedbackConfiguration

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
