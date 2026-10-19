import Foundation
import CYAppCore

/// No bootstrap, UI module, network registration or optional implementation.
public enum CoreConsumer {
    public static func check() throws -> Bool {
        struct Value: Decodable { let name: String }
        let value = try Value.decode(jsonString: #"{"name":"external"}"#)
        var request = URLRequest(url: URL(string: "https://example.test?token=FAKE_QUERY")!)
        request.setValue("FAKE_CREDENTIAL", forHTTPHeaderField: "Authorization")
        return value.name == "external" && "abc".truncated(to: 0).isEmpty
            && [1, 2].sample(-1).isEmpty && Double.nan.formattedAsBytes() == "nan"
            && !request.cURL.contains("FAKE_")
    }
}
