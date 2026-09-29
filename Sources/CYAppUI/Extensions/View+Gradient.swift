import SwiftUI

extension View {

    public func linearGradient(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        background(
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
        )
    }

    public func linearGradientBackground(
        _ colors: Color...,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        linearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }

    public func radialGradient(
        colors: [Color],
        center: UnitPoint = .center,
        startRadius: CGFloat = 0,
        endRadius: CGFloat = 200
    ) -> some View {
        background(
            RadialGradient(
                colors: colors,
                center: center,
                startRadius: startRadius,
                endRadius: endRadius
            )
        )
    }

    public func angularGradient(
        colors: [Color],
        center: UnitPoint = .center,
        angle: Angle = .degrees(0)
    ) -> some View {
        background(
            AngularGradient(colors: colors, center: center, angle: angle)
        )
    }

    public func gradientBorder(
        colors: [Color],
        width: CGFloat = 1,
        cornerRadius: CGFloat = 0
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width)
        )
    }
}
