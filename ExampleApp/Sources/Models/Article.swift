import Foundation

// MARK: - 业务模型（网络域）
//
// 这是一个“真实 Model”示例：由接口返回、遵循 Codable + Sendable + Identifiable，
// 供 Home Feature 与 ArticleService 使用。宿主新项目按同样方式定义自己的模型。

struct Article: Identifiable, Codable, Sendable, Hashable {
    let id: Int
    let title: String
    let summary: String
    let url: String
}

extension Article {
    /// ExampleApp 的演示数据，由 MockNetworkClient 返回，保证无后端也能运行。
    static let samples: [Article] = [
        Article(
            id: 1,
            title: "Swift 6 并发：从 @unchecked 到 Sendable",
            summary: "梳理数据竞争安全检查，以及如何把旧代码迁移到编译器可验证的并发模型。",
            url: "https://example.com/articles/swift6-concurrency"
        ),
        Article(
            id: 2,
            title: "SwiftData 渐进式接入",
            summary: "从 PersistenceController 到 Repository，如何只保留基础设施、业务模型留在宿主。",
            url: "https://example.com/articles/swiftdata-repository"
        ),
        Article(
            id: 3,
            title: "可裁剪的模块化设计",
            summary: "Network、Image、Persistence 作为可选产品，让不同 App 只引入真正需要的能力。",
            url: "https://example.com/articles/modular-design"
        ),
        Article(
            id: 4,
            title: "DI 能力拆分：Base 与 Capability",
            summary: "用协议组合表达“这个 Feature 需要网络能力”，而不是让所有容器都背上网关。",
            url: "https://example.com/articles/di-capability"
        ),
        Article(
            id: 5,
            title: "SwiftUI 路由的单一实例原则",
            summary: "Router 要么全程使用 .shared，要么注入同一个实例，混用会导致状态不一致。",
            url: "https://example.com/articles/router-single-instance"
        )
    ]
}
