import LocalAuthentication

// MARK: - 生物识别认证工具
//
// 封装 Face ID / Touch ID 的 async/await 调用。
//
// 用法：
// ```swift
// if CYBiometricAuth.isAvailable {
//     let type = CYBiometricAuth.availableType.displayName  // "Face ID"
//     try await CYBiometricAuth.authenticate(reason: "解锁安全数据")
// }
// ```

public final class CYBiometricAuth {
    
    private init() {}
    
    /// 设备支持的生物识别类型
    public enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
        
        public var displayName: String {
            switch self {
            case .none: return "biometric_type_none".cyLocalized
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
    }
    
    /// 生物识别认证可能发生的错误
    public enum CYBiometricError: Error, LocalizedError {
        case notAvailable
        case notEnrolled
        case lockout
        case cancelled
        case failed
        case unknown(Error)
        
        public var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "biometric_not_available".cyLocalized
            case .notEnrolled:
                return "biometric_not_enrolled".cyLocalized
            case .lockout:
                return "biometric_lockout".cyLocalized
            case .cancelled:
                return "biometric_cancelled".cyLocalized
            case .failed:
                return "biometric_failed".cyLocalized
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
    
    /// 返回设备可用的生物识别类型
    public static var availableType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }
    
    /// 设备是否支持生物识别认证
    public static var isAvailable: Bool {
        return availableType != .none
    }
    
    /// 使用生物识别进行身份验证
    /// - Parameter reason: 展示给用户的认证原因
    /// - Returns: 认证成功返回 true
    @discardableResult
    public static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        // 设置密码回退按钮的标题；localizedCancelTitle 是「取消」按钮，不能写成「使用密码」。
        context.localizedFallbackTitle = "biometric_fallback_password".cyLocalized
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            guard let laError = error as? LAError else {
                throw CYBiometricError.unknown(error ?? NSError(domain: "com.cyapp.biometric", code: -1))
            }
            
            switch laError.code {
            case .biometryNotAvailable:
                throw CYBiometricError.notAvailable
            case .biometryNotEnrolled:
                throw CYBiometricError.notEnrolled
            case .biometryLockout:
                throw CYBiometricError.lockout
            default:
                throw CYBiometricError.unknown(laError)
            }
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw CYBiometricError.failed
            }
            return true
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw CYBiometricError.cancelled
            case .biometryLockout:
                throw CYBiometricError.lockout
            default:
                throw CYBiometricError.failed
            }
        } catch {
            throw CYBiometricError.unknown(error)
        }
    }
}
