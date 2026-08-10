import Foundation

@propertyWrapper
public struct CYAppStorage<Value: Codable>: @unchecked Sendable {

    private let key: String
    private let defaultValue: Value
    private let defaults: UserDefaults

    public init(wrappedValue: Value, _ key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.defaults = defaults
    }

    public var wrappedValue: Value {
        get {
            guard let data = defaults.data(forKey: key) else { return defaultValue }
            return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    public var projectedValue: CYAppStorage<Value> { self }

    public func remove() {
        defaults.removeObject(forKey: key)
    }
}

extension CYAppStorage where Value: ExpressibleByNilLiteral {
    public init(_ key: String, defaults: UserDefaults = .standard) {
        self.init(wrappedValue: nil, key, defaults: defaults)
    }
}

extension CYAppStorage where Value == Bool {
    public init(_ key: String, defaults: UserDefaults = .standard) {
        self.init(wrappedValue: false, key, defaults: defaults)
    }
}

extension CYAppStorage where Value == Int {
    public init(_ key: String, defaults: UserDefaults = .standard) {
        self.init(wrappedValue: 0, key, defaults: defaults)
    }
}

extension CYAppStorage where Value == Double {
    public init(_ key: String, defaults: UserDefaults = .standard) {
        self.init(wrappedValue: 0.0, key, defaults: defaults)
    }
}

extension CYAppStorage where Value == String {
    public init(_ key: String, defaults: UserDefaults = .standard) {
        self.init(wrappedValue: "", key, defaults: defaults)
    }
}
