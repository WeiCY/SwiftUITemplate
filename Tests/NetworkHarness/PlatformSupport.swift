// Linux-only validation support, never compiled into the distributed library.
// The harness uses production networking sources and real Alamofire/FoundationNetworking.
// OSLog output and bundle localization are deliberately outside its validation scope.
import Foundation
import FoundationNetworking

public typealias URLRequest = FoundationNetworking.URLRequest
public typealias URLResponse = FoundationNetworking.URLResponse
public typealias HTTPURLResponse = FoundationNetworking.HTTPURLResponse
public typealias URLSessionConfiguration = FoundationNetworking.URLSessionConfiguration
public typealias URLProtocol = FoundationNetworking.URLProtocol

public enum CYLogger {
    public static let shared = Sink()
    public static let network = Sink()
    public struct Sink: Sendable {
        public func debug(_ message: String) {}
        public func error(_ message: String) {}
    }
}

public extension String {
    var cyLocalized: String { self }
}
