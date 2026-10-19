import XCTest
@testable import CYAppCore

final class NetworkRedactionTests: XCTestCase {
    func testURLRequestAndResponseUseSameQueryRedaction() {
        let url = URL(string: "https://example.test/a?access_token=FAKE_SECRET&PaSsWoRd=FAKE_PASS&page=2")!
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        for log in [CYLoggingInterceptor.redactedRequestDescription(request),
                    CYLoggingInterceptor.redactedResponseDescription(response, data: nil)] {
            XCTAssertFalse(log.contains("FAKE_SECRET"))
            XCTAssertFalse(log.contains("FAKE_PASS"))
            XCTAssertTrue(log.contains("page=2"))
        }
    }

    func testNestedJSONAndEscapedQuotesAreRedacted() {
        let data = Data(#"{"rows":[{"TOKEN":"FAKE_\"SECRET","name":"normal"},{"Password":{"value":"FAKE_PASS"}}],"refreshToken":["FAKE_REFRESH"]}"#.utf8)
        let log = CYNetworkLogRedactor.body(data)
        for secret in ["FAKE_", "SECRET", "FAKE_PASS", "FAKE_REFRESH"] { XCTAssertFalse(log.contains(secret)) }
        XCTAssertTrue(log.contains("normal"))
    }

    func testMalformedAndNonJSONBodiesAreOmitted() {
        for value in [#"{"token":"FAKE_BROKEN""#, "password=FAKE_FORM", #""FAKE_STRING""#] {
            XCTAssertFalse(CYNetworkLogRedactor.body(Data(value.utf8)).contains("FAKE_"))
        }
    }
}
