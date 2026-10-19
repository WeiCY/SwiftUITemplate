import XCTest
import CYAppCore

final class AppStorageHelperTests: XCTestCase {
    private struct Preferences: Codable, Equatable {
        var name: String
        var choices: [Int]
    }

    func testExistingJSONBytesRoundTripAndExplicitRemovePreserveOtherKeys() throws {
        let suite = "CYStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let expected = Preferences(name: "旧数据", choices: [1, 2])
        defaults.set(try JSONEncoder().encode(expected), forKey: "existing")
        defaults.set(true, forKey: "nativePreference")
        defaults.set(["existing"], forKey: "com.cyapp.storage.savedKeys") // historical metadata must not clear data
        let storage = CYAppStorageHelper(defaults: defaults)
        XCTAssertEqual(try storage.load(Preferences.self, forKey: "existing"), expected)
        try storage.save(Preferences(name: "Updated", choices: []), forKey: "existing")
        XCTAssertEqual(try storage.load(Preferences.self, forKey: "existing")?.name, "Updated")
        storage.remove(forKey: "existing")
        XCTAssertNil(try storage.load(Preferences.self, forKey: "existing"))
        XCTAssertTrue(defaults.bool(forKey: "nativePreference"))
    }

    func testMissingCorruptAndWrongStoredTypesRemainDistinct() throws {
        let suite = "CYStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = CYAppStorageHelper(defaults: defaults)
        XCTAssertNil(try storage.load(Preferences.self, forKey: "missing"))
        let corrupt = Data("not JSON".utf8)
        defaults.set(corrupt, forKey: "corrupt")
        XCTAssertThrowsError(try storage.load(Preferences.self, forKey: "corrupt")) { XCTAssertTrue($0 is DecodingError) }
        XCTAssertEqual(defaults.data(forKey: "corrupt"), corrupt)
        defaults.set("not encoded Data", forKey: "native")
        XCTAssertThrowsError(try storage.load(Preferences.self, forKey: "native")) {
            guard case DecodingError.typeMismatch = $0 else { return XCTFail("Expected stored type error") }
        }
    }

    func testFailedEncodingPreservesOldBytesAndOriginalError() throws {
        let suite = "CYStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = CYAppStorageHelper(defaults: defaults)
        try storage.save(12.0, forKey: "value")
        let previous = defaults.data(forKey: "value")
        XCTAssertThrowsError(try storage.save(Double.nan, forKey: "value")) { XCTAssertTrue($0 is EncodingError) }
        XCTAssertEqual(defaults.data(forKey: "value"), previous)
        XCTAssertEqual(try storage.load(Double.self, forKey: "value"), 12)
    }

    func testStoredJSONDecodingErrorKeepsCodingPath() throws {
        let suite = "CYStorageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"name":"ok","choices":"wrong type"}"#.utf8), forKey: "value")
        XCTAssertThrowsError(try CYAppStorageHelper(defaults: defaults).load(Preferences.self, forKey: "value")) {
            guard case DecodingError.typeMismatch(_, let context) = $0 else { return XCTFail("Expected original decoding error") }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["choices"])
        }
    }
}
