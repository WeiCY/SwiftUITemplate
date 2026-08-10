import Foundation
#if os(iOS)
import UIKit
#endif

extension URL {

    // MARK: - Query Parameters

    public func appendingQueryItems(_ items: [String: String]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var existing = components.queryItems ?? []
        for (key, value) in items {
            existing.removeAll { $0.name == key }
            existing.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = existing.isEmpty ? nil : existing
        return components.url ?? self
    }

    public func removingQueryItems() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = nil
        return components.url ?? self
    }

    // MARK: - Components

    public var domain: String? {
        host
    }

    public var urlPathComponents: [String] {
        (self as NSURL).pathComponents?.filter { $0 != "/" } ?? []
    }

    // MARK: - Validation

    public var isHTTP: Bool {
        scheme == "http" || scheme == "https"
    }

    public var isFile: Bool {
        isFileURL
    }

    // MARK: - Building

    public static func build(
        scheme: String = "https",
        host: String,
        path: String = "",
        queryItems: [URLQueryItem]? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems
        return components.url
    }

    // MARK: - External App

    #if os(iOS)
    @MainActor
    public func openInBrowser() {
        UIApplication.shared.open(self)
    }
    #endif
}
