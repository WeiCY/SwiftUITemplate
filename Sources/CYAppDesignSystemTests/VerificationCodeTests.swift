import XCTest
@testable import CYAppDesignSystem

final class VerificationCodeTests: XCTestCase {
    func testInitialExternalAndLengthUpdatesNormalizeWithoutCompletion() {
        var editing = CYVerificationCodeEditingState(value: "1a２2٣3 456789", length: 6)
        XCTAssertEqual(editing.value, "123456")
        editing.synchronize("9８87x654321", length: 4)
        XCTAssertEqual(editing.value, "9876")
        XCTAssertNil(editing.edit("9876", length: 4), "External full value must not complete again on an unchanged edit")
        editing.synchronize("", length: 6)
        XCTAssertEqual(editing.value, "")
    }

    func testPasteMixedCharactersAndOverlongInputCompleteOnce() {
        var editing = CYVerificationCodeEditingState(value: "", length: 6)
        XCTAssertEqual(editing.edit("a12-3 ٤456xyz789", length: 6), "123456")
        XCTAssertNil(editing.edit("123456789", length: 6))
        XCTAssertNil(editing.edit("1a2b3c4d5e6", length: 6))
        XCTAssertEqual(editing.value, "123456")
    }

    func testDeleteClearReenterAndDifferentCompleteValue() {
        var editing = CYVerificationCodeEditingState(value: "", length: 3)
        XCTAssertNil(editing.edit("1", length: 3))
        XCTAssertNil(editing.edit("12", length: 3))
        XCTAssertEqual(editing.edit("123", length: 3), "123")
        XCTAssertNil(editing.edit("12", length: 3))
        XCTAssertEqual(editing.edit("123", length: 3), "123")
        XCTAssertEqual(editing.edit("456", length: 3), "456")
        XCTAssertNil(editing.edit("", length: 3))
        XCTAssertEqual(editing.edit("456", length: 3), "456")
    }

    func testDisabledEditsDoNotMutateButExternalValuesStillNormalize() {
        var editing = CYVerificationCodeEditingState(value: "12", length: 3)
        XCTAssertNil(editing.edit("123", length: 3, isEnabled: false))
        XCTAssertEqual(editing.value, "12")
        editing.synchronize("abc٣345", length: 3)
        XCTAssertEqual(editing.value, "345")
        XCTAssertNil(editing.edit("345", length: 3))
    }

    func testInvalidLengthAndLongCodesHaveDefinedBounds() {
        XCTAssertEqual(CYVerificationCodeEditingState.normalized("ab12", length: 0), "1")
        XCTAssertEqual(CYVerificationCodeEditingState.normalized("１２٣٤👨‍👩‍👧‍👦", length: 6), "")
        XCTAssertEqual(CYVerificationCodeEditingState.normalized("012345678901234567890123999", length: 24), "012345678901234567890123")
        XCTAssertEqual(CYVerificationCodeEditingState.normalized("123", length: Int.max), "123")
    }
}
