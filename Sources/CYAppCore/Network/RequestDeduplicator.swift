import Foundation
import CryptoKit

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
    private struct TaskKey: Hashable {
        let key: String
        let resultType: ObjectIdentifier
    }
    private var tasks: [TaskKey: TaskWrapper] = [:]

    public init() {}

    /// Task 包装器（用于类型擦除，标记为 @unchecked Sendable）
    private struct TaskWrapper: @unchecked Sendable {
        let id = UUID()
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
        let taskKey = TaskKey(key: key, resultType: ObjectIdentifier(T.self))
        if let wrapper = tasks[taskKey],
           let existingTask = wrapper.getTask(as: T.self) {
            return try await existingTask.value
        }

        let task = Task<T, Error> { @Sendable in
            try await action()
        }

        let wrapper = TaskWrapper(task)
        tasks[taskKey] = wrapper
        defer {
            // 取消后可能已有同 key 的替代任务，只移除自己的登记。
            if tasks[taskKey]?.id == wrapper.id { tasks[taskKey] = nil }
        }

        return try await task.value
    }

    /// 取消指定 key 的请求
    public func cancel(key: String) {
        for taskKey in tasks.keys.filter({ $0.key == key }) {
            tasks.removeValue(forKey: taskKey)?.cancel()
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
    /// Stable digest of the same structured identity used by endpoint-specific mocks.
    public var deduplicationKey: String {
        guard let data = try? encodedRequestIdentity() else { return UUID().uuidString }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
        try await deduplicator.execute(key: endpoint.deduplicationKey + ":body=" + (try bodyFingerprint(body, strategy: endpoint.keyEncodingStrategy))) {
            try await self.request(endpoint, body: body)
        }
    }
}

/// 生成 Encodable body 的确定性指纹（纳入去重键）
private func bodyFingerprint<B: Encodable>(_ body: B, strategy: JSONEncoder.KeyEncodingStrategy) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.keyEncodingStrategy = strategy
    let data = try encoder.encode(body)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
