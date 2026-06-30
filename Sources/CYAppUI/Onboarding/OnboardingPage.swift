import Foundation

/// 新手引导页数据模型
/// 请根据你的 App 内容修改以下引导页
public struct CYOnboardingPage: Identifiable {
    public let id = UUID()
    public let icon: String       // SF Symbol 名称
    public let title: String
    public let description: String
    
    public init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }
    
    /// 所有引导页内容 — 请替换为你的 App 介绍
    public static let allPages: [CYOnboardingPage] = [
        CYOnboardingPage(
            icon: "sparkles",
            title: "欢迎使用",
            description: "这是一个基于 SwiftUI 的现代化应用模板。\n开箱即用，快速启动你的项目。"
        ),
        CYOnboardingPage(
            icon: "square.stack.3d.up.fill",
            title: "完整的架构基础",
            description: "内置 MVVM 分层架构、网络层、缓存管理、\n路由系统、设计系统等核心基础设施。"
        ),
        CYOnboardingPage(
            icon: "rocket.fill",
            title: "开始开发",
            description: "参考 SampleFeature 示例，\n按照相同的模式添加你的业务功能。"
        )
    ]
}
