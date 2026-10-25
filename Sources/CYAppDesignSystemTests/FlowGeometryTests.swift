import SwiftUI
import XCTest
@testable import CYAppDesignSystem

final class FlowGeometryTests: XCTestCase {
    func testInfiniteProposalUsesFiniteContentWidth() {
        XCTAssertNil(CYFlowGeometry.finiteWidth(.infinity))
        let layout = CYFlowGeometry(sizes: [CGSize(width: 20, height: 10), CGSize(width: 30, height: 12)],
                                    maxWidth: .infinity, spacing: 8, lineSpacing: 4)
        XCTAssertEqual(layout.width, 58)
        XCTAssertEqual(layout.height, 12)
    }

    func testWrappingUsesTallestItemAndRowSpacing() {
        let layout = CYFlowGeometry(sizes: [CGSize(width: 30, height: 20), CGSize(width: 50, height: 10)],
                                    maxWidth: 60, spacing: 8, lineSpacing: 4)
        XCTAssertEqual(layout.frames[1].origin, CGPoint(x: 0, y: 24))
        XCTAssertEqual(layout.height, 34)
    }

    func testEmptyAndInvalidSpacingProduceFiniteGeometry() {
        let empty = CYFlowGeometry(sizes: [], maxWidth: 100, spacing: .nan, lineSpacing: .infinity)
        XCTAssertEqual(empty.width, 0)
        XCTAssertEqual(empty.height, 0)
        let layout = CYFlowGeometry(sizes: [CGSize(width: 10, height: 10), CGSize(width: 10, height: 10)],
                                    maxWidth: 10, spacing: -1, lineSpacing: .nan)
        XCTAssertEqual(layout.frames[1].origin, CGPoint(x: 0, y: 10))
        XCTAssertEqual(layout.height, 20)
    }
}
