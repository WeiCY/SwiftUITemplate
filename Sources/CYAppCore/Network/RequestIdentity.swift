import Foundation

private struct DeduplicationQuery: Encodable {
    let name: String
    let value: String?
}
private struct DeduplicationIdentity: Encodable {
    let method: String
    let path: String
    let query: [DeduplicationQuery]
    let body: CYRequestParams?
    let headers: [String: String]?
    let authentication: String
}

extension CYEndpoint {
    /// Preserve query order, repeated names and nil values; separators cannot collide.
    /// Used for matching mocks as well as hashing in-flight requests.
    func encodedRequestIdentity() throws -> Data {
        let identity = DeduplicationIdentity(
            method: method.rawValue, path: path,
            query: (queryItems ?? []).map { DeduplicationQuery(name: $0.name, value: $0.value) },
            body: body, headers: headers, authentication: String(describing: authentication)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(identity)
    }
}
