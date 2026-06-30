import Foundation
import OSLog

// MARK: - 统一日志工具
//
// 封装 os.Logger，提供：
// - 多级日志过滤（debug / info / warning / error / critical）
// - 自动附带文件名、行号、函数名
// - 分类日志（网络 / UI / 数据库 / 通用）
// - 环境感知（Release 模式自动过滤 debug 日志）
//
// ## 基本用法
// ```swift
// CYLogger.shared.info("用户登录成功")
// CYLogger.shared.debug("接口返回: \(data)")
// CYLogger.shared.error("请求失败", error: networkError)
// ```
//
// ## 分类日志
// ```swift
// let netLog = CYLogger(category: "Network")
// netLog.debug("发送请求: \(url)")
//
// let dbLog = CYLogger(category: "Database")
// dbLog.info("查询完成，返回 \(count) 条记录")
// ```
//
// ## 设置最低日志级别
// ```swift
// CYLogger.shared.setMinimumLevel(.warning)  // 只输出 warning 及以上
// ```

/// 日志级别
public enum CYLogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: CYLogLevel, rhs: CYLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// 对应的 OSLogType
    fileprivate var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    /// 日志前缀图标
    fileprivate var prefix: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
}

public final class CYLogger {
    
    /// 全局共享实例
    public static let shared = CYLogger()
    
    // MARK: - 预定义分类实例
    
    /// 网络层日志
    public static let network = CYLogger(category: "Network")
    /// UI 层日志
    public static let ui = CYLogger(category: "UI")
    /// 数据库日志
    public static let database = CYLogger(category: "Database")
    /// 认证日志
    public static let auth = CYLogger(category: "Auth")
    /// 缓存日志
    public static let cache = CYLogger(category: "Cache")
    
    /// 日志分类
    private let category: String
    
    /// os.Logger 实例
    private let logger: os.Logger
    
    /// 最低日志级别（低于此级别的日志会被过滤）
    private var minimumLevel: CYLogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()
    
    /// 初始化（可指定分类）
    public init(category: String = "App") {
        self.category = category
        self.logger = os.Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.myapp",
            category: category
        )
    }
    
    // MARK: - 日志级别控制
    
    /// 设置最低日志级别
    ///
    /// - Parameter level: 低于此级别的日志将被过滤
    public func setMinimumLevel(_ level: CYLogLevel) {
        self.minimumLevel = level
    }
    
    // MARK: - 日志输出
    
    /// Debug 级别日志（开发调试用）
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// Info 级别日志（一般信息）
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// Warning 级别日志（潜在问题）
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// Error 级别日志（错误）
    public func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
            if let nsError = error as NSError? {
                logMessage += " | Domain: \(nsError.domain), Code: \(nsError.code)"
            }
        }
        log(level: .error, message: logMessage, file: file, function: function, line: line)
    }
    
    /// Critical 级别日志（严重错误，可能导致崩溃）
    public func critical(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        log(level: .critical, message: logMessage, file: file, function: function, line: line)
    }
    
    // MARK: - 内部实现
    
    /// 内部统一日志输出
    private func log(level: CYLogLevel, message: String, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(level.prefix) [\(category)] \(fileName):\(line) \(function) -> \(message)"
        
        switch level.osLogType {
        case .debug:
            logger.debug("\(formattedMessage, privacy: .public)")
        case .info:
            logger.info("\(formattedMessage, privacy: .public)")
        case .default:
            logger.log("\(formattedMessage, privacy: .public)")
        case .error:
            logger.error("\(formattedMessage, privacy: .public)")
        case .fault:
            logger.fault("\(formattedMessage, privacy: .public)")
        default:
            logger.log("\(formattedMessage, privacy: .public)")
        }
    }
}
