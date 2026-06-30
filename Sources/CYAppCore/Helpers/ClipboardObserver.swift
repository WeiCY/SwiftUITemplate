#if canImport(UIKit)
import UIKit
import Observation

/// 剪贴板内容监听器
///
/// 适用于口令识别、分享链接、淘口令等场景。
/// App 回到前台时自动检测剪贴板变化。
///
/// 用法：
/// ```swift
/// // App 入口处
/// CYClipboardObserver.shared.onClipboardChange = { content in
///     if content.hasPrefix("https://") {
///         // 检测到链接，提示打开
///     }
/// }
///
/// // 或检查当前剪贴板
/// if let url = CYClipboardObserver.shared.currentURL { ... }
/// ```
@Observable
@MainActor
public final class CYClipboardObserver {
    
    public nonisolated static let shared = CYClipboardObserver()
    
    /// 当前剪贴板文本内容
    public var currentContent: String?
    
    /// 剪贴板变化回调
    public var onClipboardChange: ((String) -> Void)?
    
    /// 上次检测的剪贴板内容（用于去重）
    @ObservationIgnored
    private var lastContent: String?
    
    public nonisolated init() {}
    
    /// 检测剪贴板变化（在 App 入口的 onChange(of: scenePhase) 中调用）
    public func check() {
        let content = UIPasteboard.general.string
        guard content != lastContent else { return }
        
        lastContent = content
        currentContent = content
        
        if let content = content, !content.isEmpty {
            onClipboardChange?(content)
        }
    }
    
    /// 当前剪贴板中的 URL（如有）
    public var currentURL: URL? {
        guard let text = currentContent else { return nil }
        return URL(string: text)
    }
    
    /// 清除剪贴板
    public func clear() {
        UIPasteboard.general.string = ""
        currentContent = nil
        lastContent = nil
    }
    
    /// 读取并清除（一次性读取，如口令场景）
    public func readAndClear() -> String? {
        let content = currentContent
        clear()
        return content
    }
}
#endif
