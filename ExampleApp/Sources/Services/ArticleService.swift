import Foundation
import CYAppCore

// MARK: - 接口定义

enum ArticleEndpoint: CYEndpoint {
    case list

    var path: String {
        switch self {
        case .list: "/articles"
        }
    }

    var method: CYHTTPMethod {
        switch self {
        case .list: .get
        }
    }
}

// MARK: - Service 协议
//
// ViewModel 只依赖协议，便于替换实现（真实网络 / Mock / Preview）。
// 该 Service 需要网络能力，因此由宿主在组合时注入 `CYNetworkClientProtocol`。

@MainActor
protocol ArticleServiceProtocol: AnyObject {
    /// 演示用：置为 true 后下次请求直接抛错，用于展示 error / retry 状态。
    var simulateFailure: Bool { get set }
    func fetchArticles() async throws -> [Article]
}

// MARK: - 真实实现

@MainActor
final class ArticleService: ArticleServiceProtocol {
    private let client: any CYNetworkClientProtocol
    var simulateFailure = false

    /// - Parameter client: 网络客户端。从 DI 取用，体现“网络 Feature 依赖 NetworkProviding”。
    init(client: any CYNetworkClientProtocol = CYAppContainer.shared.networkClient) {
        self.client = client
    }

    func fetchArticles() async throws -> [Article] {
        if simulateFailure {
            throw CYNetworkError.noConnection
        }
        return try await client.request(ArticleEndpoint.list)
    }
}
