import XCTest
import CYAppCore

final class ReuseBoundaryTests: XCTestCase {
    func testSamplingNegativeAndOversizedCounts() {
        XCTAssertEqual([1, 2, 3].sample(-1), [])
        XCTAssertEqual([Int]().sample(10), [])
        XCTAssertEqual(Set([1, 2, 3].sample(Int.max)), Set([1, 2, 3]))
        XCTAssertEqual([1, 2, 3].chunked(into: Int.max), [[1, 2, 3]])
        XCTAssertEqual([1, 2].chunked(into: 0), [[1, 2]]) // compatibility
    }

    func testByteFormattingDoesNotTrapOnExternalNumericInput() {
        for value in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, Double(Int64.max)] {
            XCTAssertEqual(value.formattedAsBytes(), String(value))
        }
        XCTAssertEqual(0.0.formattedAsBytes(), ByteCountFormatter.string(fromByteCount: 0, countStyle: .file))
        XCTAssertEqual(1536.9.formattedAsBytes(), ByteCountFormatter.string(fromByteCount: 1536, countStyle: .file))
    }

    func testCurlDefaultsToSharedRedactionRules() {
        var request = URLRequest(url: URL(string: "https://example.test/path?token=FAKE_QUERY&name=visible")!)
        request.setValue("Bearer FAKE_HEADER", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"nested":{"password":"FAKE_BODY"},"name":"visible"}"#.utf8)
        let command = request.cURL
        for secret in ["FAKE_QUERY", "FAKE_HEADER", "FAKE_BODY"] { XCTAssertFalse(command.contains(secret)) }
        XCTAssertTrue(command.contains("visible"))
        XCTAssertTrue(command.contains("***"))
        XCTAssertTrue(request.cURL(redactingSensitiveData: false).contains("FAKE_HEADER"))
    }

    func testCurlQuotesShellMetacharactersAndSingleQuotes() {
        var request = URLRequest(url: URL(string: "https://example.test/$(FAKE_COMMAND)")!)
        request.httpBody = Data("O'Reilly $(FAKE_BODY)".utf8)
        let raw = request.cURL(redactingSensitiveData: false)
        XCTAssertTrue(raw.hasPrefix("curl 'https://"))
        XCTAssertTrue(raw.contains("--data-raw 'O'\\''Reilly $(FAKE_BODY)'"))
        XCTAssertFalse(request.cURL.contains("FAKE_BODY"), "Unstructured default body must be omitted")
    }
}
