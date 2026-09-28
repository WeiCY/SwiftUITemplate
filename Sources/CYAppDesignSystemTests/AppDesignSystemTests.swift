import XCTest
import SwiftUI
import CYAppDesignSystem

#if canImport(AppKit)
import AppKit
#endif

// MARK: - 设计系统补充测试
//
// 覆盖历史上「零单测」的高风险模块：Color+Hex（非法输入应安全降级为透明、合法解析正确）。
// 注意：SwiftUI 的 `Color` 在带透明度时 `==` 不可靠（相同 debug 描述仍判不等），
// 故对透明度/通道用平台 NSColor 分量校验，不透明度单独断言。

final class AppDesignSystemTests: XCTestCase {

    private let sRGBRed = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
    private let sRGBGreen = Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1)
    private let sRGBClear = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0)

    func testColorHexValidRed() {
        XCTAssertEqual(Color(hex: "FF0000"), sRGBRed)
    }

    func testColorHexValidGreenWithHash() {
        XCTAssertEqual(Color(hex: "#00FF00"), sRGBGreen)
    }

    func testColorHexInvalidReturnsClear() {
        // 非法输入应安全降级为透明色，而非崩溃
        XCTAssertEqual(Color(hex: "xyz"), sRGBClear)
        XCTAssertEqual(Color(hex: ""), sRGBClear)
        XCTAssertEqual(Color(hex: "ZZ"), sRGBClear)
    }

    // MARK: - CYAppColor 品牌色配置

    private let sRGBBlue = Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1)

    func testAppColorConfigureOverridesPrimaryAndAccent() {
        defer { CYAppColor.reset() }

        CYAppColor.configure(primary: sRGBRed, accent: sRGBBlue)

        XCTAssertEqual(CYAppColor.primary, sRGBRed)
        XCTAssertEqual(CYAppColor.accent, sRGBBlue)
    }

    func testAppColorConfigurePartialKeepsOtherValue() {
        defer { CYAppColor.reset() }

        CYAppColor.configure(accent: sRGBBlue)

        XCTAssertEqual(CYAppColor.accent, sRGBBlue)
        XCTAssertEqual(CYAppColor.primary, Color.indigo, "未传入的 primary 应保持默认")
    }

    func testAppColorResetRestoresDefaults() {
        CYAppColor.configure(primary: sRGBRed, accent: sRGBGreen)
        CYAppColor.reset()

        XCTAssertEqual(CYAppColor.primary, Color.indigo)
        XCTAssertEqual(CYAppColor.accent, Color.accentColor)
    }

    #if canImport(AppKit)
    func testColorHexRRGGBBAAAlphaValue() {
        // 8 位按 RRGGBBAA 解析：FF000080 -> r=FF, g=00, b=00, a=0x80(~0.5)
        let ns = NSColor(Color(hex: "FF000080"))
        XCTAssertEqual(ns.alphaComponent, 0.5, accuracy: 0.02, "透明度应约为 0.5")
        XCTAssertEqual(ns.redComponent, 1.0, accuracy: 0.02, "红色分量应为 1")
        XCTAssertEqual(ns.greenComponent, 0.0, accuracy: 0.02, "绿色分量应为 0")
    }

    func testColorHexRRGGBBAATransparentBlue() {
        // 000080FF -> r=00, g=00, b=0x80, a=FF(不透明)
        let ns = NSColor(Color(hex: "000080FF"))
        XCTAssertEqual(ns.alphaComponent, 1.0, accuracy: 0.02, "8 位低字节为 A，应不透明")
        XCTAssertEqual(ns.blueComponent, Double(0x80) / 255.0, accuracy: 0.02, "蓝色分量应为 0x80")
    }
    #endif
}
