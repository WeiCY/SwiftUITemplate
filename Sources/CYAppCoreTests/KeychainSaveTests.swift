import XCTest
import Security
import Synchronization
@testable import CYAppCore

final class KeychainSaveTests: XCTestCase {
    func testSaveUpdatesOnlyByIdentityWithoutDeletingOldValue() throws {
        let helper = CYKeychainHelper(update: { query, values in
            let query = query as NSDictionary
            let values = values as NSDictionary
            XCTAssertEqual(query[kSecAttrService] as? String, "test.service")
            XCTAssertEqual(query[kSecAttrAccount] as? String, "test.account")
            XCTAssertNil(query[kSecValueData])
            XCTAssertNil(query[kSecAttrAccessible])
            XCTAssertEqual(values[kSecValueData] as? Data, Data("new".utf8))
            XCTAssertEqual(values[kSecAttrAccessible] as? String, kSecAttrAccessibleWhenUnlocked as String)
            return errSecSuccess
        }, add: { _ in XCTFail("Existing item should only be updated"); return errSecParam })
        try helper.save("new", service: "test.service", account: "test.account", accessibility: .whenUnlocked).get()
    }

    func testMissingItemIsAddedWithIdentityAndValues() throws {
        let helper = CYKeychainHelper(update: { _, _ in errSecItemNotFound }, add: { item in
            let item = item as NSDictionary
            XCTAssertEqual(item[kSecAttrService] as? String, "test.service")
            XCTAssertEqual(item[kSecAttrAccount] as? String, "test.account")
            XCTAssertEqual(item[kSecValueData] as? Data, Data("new".utf8))
            return errSecSuccess
        })
        try helper.save("new", service: "test.service", account: "test.account").get()
    }

    func testConcurrentInsertRetriesUpdateOnce() throws {
        let updates = Mutex(0)
        let helper = CYKeychainHelper(update: { _, _ in
            updates.withLock { count in
                count += 1
                return count == 1 ? errSecItemNotFound : errSecSuccess
            }
        }, add: { _ in errSecDuplicateItem })
        try helper.save("new", service: "test.service", account: "test.account").get()
        XCTAssertEqual(updates.withLock { $0 }, 2)
    }

    func testUpdateFailureIsReturnedWithoutAddingOrDeleting() {
        let helper = CYKeychainHelper(update: { _, _ in errSecInteractionNotAllowed }, add: { _ in
            XCTFail("Failure must not trigger add"); return errSecParam
        })
        XCTAssertThrowsError(try helper.save("new", service: "test.service", account: "test.account").get()) {
            XCTAssertEqual($0 as? CYKeychainError, .operationFailed(status: errSecInteractionNotAllowed))
        }
    }
}
