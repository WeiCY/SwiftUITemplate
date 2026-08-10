import Foundation

extension Result {

    public var value: Success? {
        if case .success(let v) = self { return v }
        return nil
    }

    public var error: Failure? {
        if case .failure(let e) = self { return e }
        return nil
    }

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isFailure: Bool {
        !isSuccess
    }

    public func getOrDefault(_ defaultValue: Success) -> Success {
        switch self {
        case .success(let v): return v
        case .failure: return defaultValue
        }
    }
}

extension Result where Success == Void {
    public static var success: Result { .success(()) }
}
