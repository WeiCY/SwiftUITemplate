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

    /// 存储正在执行的任务（使用类型擦除的 Task 包装）
    private var tasks: [String: TaskWrapper] = [:]

    public init() {}

    /// Task 包装器（用于类型擦除，标记为 @unchecked Sendable）
    private struct TaskWrapper: @unchecked Sendable {
        private let _task: Any
        let cancel: @Sendable () -> Void

        init<T: Sendable>(_ task: Task<T, Error>) {
            self._task = task
            self.cancel = { task.cancel() }
        }

        func getTask<T: Sendable>(as type: T.Type) -> Task<T, Error>? {
            _task as? Task<T, Error>
        }
    }

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
        action: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if let wrapper = tasks[key],
           let existingTask = wrapper.getTask(as: T.self) {
            return try await existingTask.value
        }

        let task = Task<T, Error> { @Sendable in
            try await action()
        }

        tasks[key] = TaskWrapper(task)

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
        if let wrapper = tasks[key] {
            wrapper.cancel()
            tasks[key] = nil
        }
    }

    /// 取消所有请求
    public func cancelAll() {
        for (_, wrapper) in tasks {
            wrapper.cancel()
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
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            let queryString = queryItems
                .sorted { $0.name < $1.name }
                .map { "\($0.name)=\($0.value ?? "")" }
                .joined(separator: "&")
            components.append(queryString)
        }
        
        if let body = body, !body.isEmpty {
            let sortedBody = body.keys.sorted().map { key in
                "\(key)=\(body[key]?.stableDescription ?? "")"
            }.joined(separator: "&")
            components.append(sortedBody)
        }
        
        return components.joined(separator: ":")
    }
}

// MARK: - 网络客户端去重便捷 API

public extension CYNetworkClientProtocol {

    /// 带去重的网络请求
    ///
    /// 相同 `deduplicationKey` 的并发请求只执行一次，复用同一结果。
    /// ```swift
    /// let user: User = try await networkClient.requestWithDeduplication(
    ///     UserEndpoint.profile, deduplicator: deduplicator
    /// )
    /// ```
    func requestWithDeduplication<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        deduplicator: CYRequestDeduplicator
    ) async throws -> T {
        try await deduplicator.execute(key: endpoint.deduplicationKey) {
            try await self.request(endpoint)
        }
    }

    /// 带去重的 POST（Encodable body 纳入去重键）
    ///
    /// 默认 `deduplicationKey` 只覆盖 `endpoint.body` 字典参数；
    /// 本方法额外将 Encodable body 的确定性指纹拼入去重键，避免不同 body 被错误合并。
    func requestWithDeduplication<B: Encodable & Sendable, T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        body: B,
        deduplicator: CYRequestDeduplicator
    ) async throws -> T {
        try await deduplicator.execute(key: endpoint.deduplicationKey + ":body=" + bodyFingerprint(body)) {
            try await self.request(endpoint, body: body)
        }
    }
}

/// 生成 Encodable body 的确定性指纹（纳入去重键）
private func bodyFingerprint<B: Encodable>(_ body: B) -> String {
    guard let data = try? JSONEncoder().encode(body) else { return "?" }
    return data.base64EncodedString()
}
