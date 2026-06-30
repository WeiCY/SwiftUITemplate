import SwiftUI

// MARK: - View 扩展
//
// 提供条件修饰符、键盘隐藏、圆角、隐藏、抖动、脉冲、截图等常用 View 操作。
//
// 用法：
// ```swift
// // 条件修饰符
// view.if(isHighlighted) { $0.foregroundStyle(.red) }
//
// // 隐藏键盘
// view.hideKeyboard()
//
// // 指定角圆角
// view.cornerRadius(12, corners: [.topLeft, .topRight])
//
// // 输入错误时抖动动画
// TextField("密码", text: $pwd)
//     .shake(trigger: showShake)
//
// // 读取视图尺寸
// view.readSize { size in print(size) }
//
// // 卡片样式
// view.cardStyle(cornerRadius: 16, padding: 20)
// ```

extension View {
    
    // MARK: - 条件修饰符
    
    /// 条件性地应用修饰符
    @ViewBuilder public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 隐藏键盘
    #if canImport(UIKit)
    public func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
    
    /// 为指定角添加圆角（iOS 16+）
    public func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: corners.contains(.topLeft) ? radius : 0,
                bottomLeadingRadius: corners.contains(.bottomLeft) ? radius : 0,
                bottomTrailingRadius: corners.contains(.bottomRight) ? radius : 0,
                topTrailingRadius: corners.contains(.topRight) ? radius : 0,
                style: .continuous
            )
        )
    }
    
    /// 条件性隐藏视图（类似 Android 的 View.GONE）
    @ViewBuilder
    public func isHidden(_ hidden: Bool, remove: Bool = true) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
    
    /// 仅在视图首次出现时执行操作
    public func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
    
    /// 将视图居中于父容器
    public func center() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
    
    /// 带圆角的边框
    public func border(_ color: Color, width: CGFloat, cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }
    
    /// 调试辅助：显示视图 frame 和尺寸
    public func debugFrame(color: Color = .red) -> some View {
        overlay(GeometryReader { geo in
            ZStack {
                Rectangle().stroke(color)
                Text("\(Int(geo.size.width))x\(Int(geo.size.height))")
                    .foregroundColor(color)
                    .font(.caption)
            }
        })
    }
    
    // MARK: - 抖动动画
    
    /// 水平抖动动画，适用于输入错误提示
    /// - 参数：
    ///   - trigger: 触发值变化时执行抖动
    ///   - amplitude: 最大水平偏移（默认 10pt）
    ///   - duration: 动画总时长（默认 0.5s）
    public func shake(trigger: Bool, amplitude: CGFloat = 10, duration: Double = 0.5) -> some View {
        modifier(ShakeModifier(trigger: trigger, amplitude: amplitude, duration: duration))
    }
    
    // MARK: - 读取尺寸
    
    /// 读取视图尺寸并通过闭包回调
    /// 用法: .readSize { size in print("Width: \(size.width)") }
    public func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
    
    // MARK: - 脉冲动画
    
    /// 持续的缩放脉冲动画
    /// - 参数：
    ///   - scale: 峰值缩放比例（默认 1.1）
    ///   - duration: 一个周期时长（默认 1.0s）
    public func pulse(scale: CGFloat = 1.1, duration: Double = 1.0) -> some View {
        modifier(PulseModifier(scale: scale, duration: duration))
    }
    
    // MARK: - 截图
    
    /// 将视图截图为 UIImage（需在主线程调用）
    #if canImport(UIKit)
    @MainActor
    public func snapshot() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    #endif
    
    // MARK: - Safe Area
    
    /// 仅在指定边忽略安全区域
    public func ignoreSafeArea(_ edges: Edge.Set) -> some View {
        self.ignoresSafeArea(edges: edges)
    }
    
    // MARK: - 卡片样式
    
    /// 应用标准卡片样式（内边距 + 背景 + 圆角 + 阴影）
    public func cardStyle(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 辅助修饰符

/// onFirstAppear 辅助修饰符
private struct FirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content.onAppear {
            if !hasAppeared {
                hasAppeared = true
                action()
            }
        }
    }
}

/// 抖动动画修饰符
private struct ShakeModifier: ViewModifier {
    let trigger: Bool
    let amplitude: CGFloat
    let duration: Double
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                guard trigger else { return }
                let steps = 6
                let stepDuration = duration / Double(steps)
                Task { @MainActor in
                    for i in 0..<steps {
                        let direction: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                        let decay = 1.0 - (CGFloat(i) / CGFloat(steps))
                        withAnimation(.easeInOut(duration: stepDuration)) {
                            offset = amplitude * direction * decay
                        }
                        try? await Task.sleep(for: .seconds(stepDuration))
                    }
                    withAnimation(.easeOut(duration: stepDuration)) {
                        offset = 0
                    }
                }
            }
    }
}

/// 脉冲动画修饰符
private struct PulseModifier: ViewModifier {
    let scale: CGFloat
    let duration: Double
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .animation(
                .easeInOut(duration: duration / 2)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preference Key

/// 尺寸 PreferenceKey
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// 纯 SwiftUI 角定义（替代 UIRectCorner）
public struct RectCorner: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// 左上角
    public static let topLeft = RectCorner(rawValue: 1 << 0)
    /// 右上角
    public static let topRight = RectCorner(rawValue: 1 << 1)
    /// 左下角
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    /// 右下角
    public static let bottomRight = RectCorner(rawValue: 1 << 3)
    /// 所有角
    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    /// 上方两个角
    public static let topCorners: RectCorner = [.topLeft, .topRight]
    /// 下方两个角
    public static let bottomCorners: RectCorner = [.bottomLeft, .bottomRight]
}
