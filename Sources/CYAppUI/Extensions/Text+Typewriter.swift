import SwiftUI

// MARK: - 打字机效果修饰符
// 逐字符动画显示文本，适用于游戏事件日志等需要沉浸式阅读的场景

public struct TypewriterModifier: ViewModifier {
    let fullText: String
    let speed: Double
    let trigger: Bool
    
    @State private var displayedText: String = ""
    @State private var typingTask: Task<Void, Never>?
    @State private var hasStarted = false
    
    public func body(content: Content) -> some View {
        Text(currentText)
            .onAppear {
                if trigger && !hasStarted {
                    hasStarted = true
                    startTypewriter()
                } else if !trigger {
                    displayedText = fullText
                }
            }
            .onChange(of: trigger) { _, newValue in
                if newValue && !hasStarted {
                    hasStarted = true
                    startTypewriter()
                }
            }
    }
    
    private var currentText: String {
        if trigger && hasStarted {
            return displayedText
        }
        return fullText
    }
    
    private func startTypewriter() {
        typingTask?.cancel()
        displayedText = ""
        
        typingTask = Task { @MainActor in
            for char in fullText {
                guard !Task.isCancelled else { return }
                displayedText.append(char)
                try? await Task.sleep(for: .seconds(speed))
            }
        }
    }
}

// MARK: - View 扩展

extension View {
    /// 打字机效果修饰符 — 逐字符动画显示文本
    /// - 参数：
    ///   - text: 要显示的完整文本
    ///   - speed: 每个字符的间隔时间（秒），默认 0.025s
    ///   - trigger: 为 true 时启动打字动画，为 false 时直接显示全文
    public func typewriter(text: String, speed: Double = 0.025, trigger: Bool = false) -> some View {
        modifier(TypewriterModifier(fullText: text, speed: speed, trigger: trigger))
    }
}
