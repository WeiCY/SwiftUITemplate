import Foundation
import CYAppCore

/// No bootstrap, UI module, network registration or optional implementation.
public enum CoreConsumer {
    public static func check() throws -> Bool {
        struct Value: Codable { let name: String }
        let value = try Value.decode(jsonString: #"{"name":"external"}"#)
        var request = URLRequest(url: URL(string: "https://example.test?token=FAKE_QUERY")!)
        request.setValue("FAKE_CREDENTIAL", forHTTPHeaderField: "Authorization")
        let suite = "CoreConsumer.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return false }
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = CYAppStorageHelper(defaults: defaults)
        defaults.set(Data(#"{"name":"legacy JSON bytes"}"#.utf8), forKey: "value")
        guard try storage.load(Value.self, forKey: "value")?.name == "legacy JSON bytes" else { return false }
        try storage.save(value, forKey: "value")
        guard try storage.load(Value.self, forKey: "value")?.name == "external" else { return false }
        storage.remove(forKey: "value")
        guard try storage.load(Value.self, forKey: "value") == nil else { return false }
        return value.name == "external" && "abc".truncated(to: 0).isEmpty
            && [1, 2].sample(-1).isEmpty && Double.nan.formattedAsBytes() == "nan"
            && !request.cURL.contains("FAKE_")
    }
}
