import Foundation

/// Explicit Codable preferences backed by JSON Data in an injected UserDefaults.
/// Missing keys return nil; wrong stored types and corrupt JSON throw without deleting data.
/// UserDefaults does not provide a throwing disk-commit/transaction guarantee.
public struct CYAppStorageHelper {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Encode before touching storage, so an encoding failure preserves the previous bytes.
    public func save<T: Encodable>(_ value: T, forKey key: String, encoder: JSONEncoder = .init()) throws {
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: String, decoder: JSONDecoder = .init()) throws -> T? {
        guard let object = defaults.object(forKey: key) else { return nil }
        guard let data = object as? Data else {
            throw DecodingError.typeMismatch(Data.self, .init(codingPath: [], debugDescription: "Expected JSON Data at key: \(key)"))
        }
        return try decoder.decode(type, from: data)
    }

    /// Removes only the explicit key. There is no global key registry or implicit clear-all.
    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
