import Foundation

// MARK: - 网络请求去重协调器

/// 网络请求去重协调器
///
/// 防止多个相同请求并发时重复执行，复用同一个结果。
/// 使用场景：
/// - 用户快速多次点击同一按钮
/// - 多个组件同时请求相同数据
/// - 页面刷新时避免重复请求
///
/// 示例：
/// ```swift
/// let deduplicator = CYRequestDeduplicator()
///
/// // 多次调用只会执行一次
/// async let task1 = deduplicator.execute(key: "user_profile") {
///     try await networkClient.request(UserEndpoint.profile)
/// }
/// async let task2 = deduplicator.execute(key: "user_profile") {
///     try await networkClient.request(UserEndpoint.profile)
/// }
///
/// let (result1, result2) = try await (task1, task2)
/// // result1 和 result2 相同，但只发起了一次网络请求
/// ```
public actor CYRequestDeduplicator {
    
    /// 存储正在执行的任务
    private var tasks: [String: Any] = [:]
    
    public init() {}
    
    /// 执行请求（带去重）
    ///
    /// - Parameters:
    ///   - key: 去重键（通常为 endpoint path + 参数的哈希）
    ///   - action: 实际的网络请求闭包
    /// - Returns: 请求结果
    ///
    /// **去重逻辑**：
    /// 1. 如果相同 key 的请求正在执行，直接复用该任务
    /// 2. 如果没有，创建新任务并缓存
    /// 3. 任务完成后，从缓存中移除
    public func execute<T: Sendable>(
        key: String,
        action: @escaping () async throws -> T
    ) async throws -> T {
        // 检查是否已有相同请求正在执行
        if let existingTask = tasks[key] as? Task<T, Error> {
            return try await existingTask.value
        }
        
        // 创建新任务
        let task = Task<T, Error> {
            try await action()
        }
        
        // 缓存任务
        tasks[key] = task
        
        // 执行并清理
        do {
            let result = try await task.value
            tasks[key] = nil
            return result
        } catch {
            tasks[key] = nil
            throw error
        }
    }
    
    /// 取消指定 key 的请求
    public func cancel(key: String) {
        if let task = tasks[key] as? Task<Any, Error> {
            task.cancel()
            tasks[key] = nil
        }
    }
    
    /// 取消所有请求
    public func cancelAll() {
        for (_, task) in tasks {
            if let task = task as? Task<Any, Error> {
                task.cancel()
            }
        }
        tasks.removeAll()
    }
}

// MARK: - Endpoint 扩展（自动生成去重键）

extension CYEndpoint {
    /// 生成请求的唯一标识符（用于去重）
    ///
    /// 规则：`method + path + queryItems + body 的哈希`
    ///
    /// 示例：
    /// ```swift
    /// UserEndpoint.profile.deduplicationKey  // "GET:/api/user/profile"
    /// UserEndpoint.list(page: 2).deduplicationKey  // "GET:/api/user/list?page=2"
    /// ```
    public var deduplicationKey: String {
        var components: [String] = [method.rawValue, path]
        
        // 添加 query 参数
        if let queryItems = queryItems, !queryItems.isEmpty {
            let queryString = queryItems
                .sorted { $0.name < $1.name }
                .map { "\($0.name)=\($0.value ?? "")" }
                .joined(separator: "&")
            components.append(queryString)
        }
        
        // 添加 body 参数（如果有）
        if let body = body {
            let bodyString = body.keys.sorted().map { "\($0)=\(body[$0]!)" }.joined(separator: "&")
            components.append(bodyString)
        }
        
        return components.joined(separator: ":")
    }
}

// MARK: - NetworkClient 扩展（集成去重）

extension CYNetworkClient {
    /// 带去重的网络请求
    ///
    /// 自动使用 `endpoint.deduplicationKey` 作为去重键。
    /// 适用于幂等的 GET 请求，POST/PUT/DELETE 请求慎用。
    ///
    /// 示例：
    /// ```swift
    /// // 用户多次点击，只发起一次请求
    /// let user: User = try await networkClient.requestWithDeduplication(
    ///     UserEndpoint.profile,
    ///     deduplicator: appContainer.requestDeduplicator
    /// )
    /// ```
    public func requestWithDeduplication<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        deduplicator: CYRequestDeduplicator
    ) async throws -> T {
        try await deduplicator.execute(key: endpoint.deduplicationKey) {
            try await self.request(endpoint)
        }
    }
    
    /// 带去重的原始请求
    public func requestRawWithDeduplication<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        deduplicator: CYRequestDeduplicator
    ) async throws -> CYAPIResponse<T> {
        try await deduplicator.execute(key: endpoint.deduplicationKey) {
            try await self.requestRaw(endpoint)
        }
    }
}
