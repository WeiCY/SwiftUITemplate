// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CYSwiftTemplate",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CYAppCore", targets: ["CYAppCore"]),
        .library(name: "CYAppDesignSystem", targets: ["CYAppDesignSystem"]),
        .library(name: "CYAppUI", targets: ["CYAppUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.0.0"),
    ],
    targets: [
        // Layer 0: Foundation 纯逻辑，无 SwiftUI
        .target(
            name: "CYAppCore",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "Factory", package: "Factory"),
            ],
            path: "Sources/CYAppCore",
            resources: [.process("Resources")]
        ),
        // Layer 1: SwiftUI 设计系统 + UI 组件
        .target(
            name: "CYAppDesignSystem",
            dependencies: ["CYAppCore"],
            path: "Sources/CYAppDesignSystem"
        ),
        // Layer 2: SwiftUI 功能组件 + 路由 + 全局视图
        .target(
            name: "CYAppUI",
            dependencies: ["CYAppCore", "CYAppDesignSystem"],
            path: "Sources/CYAppUI"
        ),
        // Tests
        .testTarget(
            name: "CYAppCoreTests",
            dependencies: ["CYAppCore"],
            path: "Sources/CYAppCoreTests"
        ),
        .testTarget(
            name: "CYAppDesignSystemTests",
            dependencies: ["CYAppDesignSystem"],
            path: "Sources/CYAppDesignSystemTests"
        ),
        .testTarget(
            name: "CYAppUITests",
            dependencies: ["CYAppUI", "CYAppCore"],
            path: "Sources/CYAppUITests"
        ),
        // 可运行 Demo（业务接入参考）
        .executableTarget(
            name: "ExampleApp",
            dependencies: ["CYAppCore", "CYAppDesignSystem", "CYAppUI"],
            path: "ExampleApp/Sources"
        ),
    ],
    // 直接以 Swift 6 语言模式编译（不再依赖 upcoming feature 开关）
    swiftLanguageModes: [.v6]
)
