import CYAppCore
import CYFeedbackStyle
import CYAppDesignSystem
import FactoryKit

/// 用 defer restore() 恢复进入测试前的值与 Factory 注册/缓存，而非假设默认值。
/// 全局配置测试应在同一进程串行运行；并行测试使用独立实例或进程。
@MainActor
public final class CYGlobalTestState {
    private let constants = CYAppConstants.configuration
    private let policy = CYBusinessCodePolicy.shared.withLock { $0 }
    private let level = CYLogger.globalMinimumLevel
    private let sharedLevel = CYLogger.shared.minimumLevelOverride
    private let design = CYDesignConfiguration.current
    private let toast = CYFeedbackConfiguration.shared.toastStyle
    private let loading = CYFeedbackConfiguration.shared.loadingStyle
    private let error = CYFeedbackConfiguration.shared.errorStyle
    private var restored = false

    public init() { Container.shared.manager.push() }

    /// Factory singleton cache is TaskLocal and is not part of manager.push/pop.
    /// Use this scope when changing registrations so both cache layers are restored.
    public static func withScope<T>(_ operation: () throws -> T) rethrows -> T {
        try Scope.$singleton.withValue(Scope.singleton.clone()) {
            let state = CYGlobalTestState()
            defer { state.restore() }
            return try operation()
        }
    }

    public func restore() {
        guard !restored else { return }
        restored = true
        CYAppConstants.configure(constants)
        let policy = policy
        CYBusinessCodePolicy.configure { $0 = policy }
        CYLogger.setGlobalMinimumLevel(level)
        if let sharedLevel { CYLogger.shared.setMinimumLevel(sharedLevel) } else { CYLogger.shared.resetMinimumLevel() }
        CYDesignConfiguration.configure(design)
        CYFeedbackConfiguration.configure(toastStyle: toast, loadingStyle: loading, errorStyle: error)
        Container.shared.manager.pop()
    }
}
