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
        .library(name: "CYFeedbackStyle", targets: ["CYFeedbackStyle"]),
        .library(name: "CYAppDesignSystem", targets: ["CYAppDesignSystem"]),
        .library(name: "CYAppUI", targets: ["CYAppUI"]),
        .library(name: "CYAppPersistence", targets: ["CYAppPersistence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.12.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.11.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.3.2"),
    ],
    targets: [
        // Layer 0: Foundation 纯逻辑，无 SwiftUI
        .target(
            name: "CYAppCore",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "FactoryKit", package: "Factory"),
            ],
            path: "Sources/CYAppCore",
            resources: [.process("Resources")]
        ),
        // Layer 0 UI: 共享反馈样式，不依赖业务模块
        .target(
            name: "CYFeedbackStyle",
            path: "Sources/CYFeedbackStyle"
        ),
        // Layer 1: SwiftUI 设计系统 + UI 组件
        .target(
            name: "CYAppDesignSystem",
            dependencies: ["CYAppCore", "CYFeedbackStyle"],
            path: "Sources/CYAppDesignSystem"
        ),
        // Layer 2: SwiftUI 功能组件 + 路由 + 全局视图
        .target(
            name: "CYAppUI",
            dependencies: ["CYAppCore", "CYFeedbackStyle", "CYAppDesignSystem"],
            path: "Sources/CYAppUI"
        ),
        // Layer 3: SwiftData 持久化（可选引入，不依赖任何业务模块）
        .target(
            name: "CYAppPersistence",
            path: "Sources/CYAppPersistence"
        ),
        // Tests
        .testTarget(
            name: "CYAppCoreTests",
            dependencies: ["CYAppCore"],
            path: "Sources/CYAppCoreTests"
        ),
        .testTarget(
            name: "CYFeedbackStyleTests",
            dependencies: ["CYFeedbackStyle"],
            path: "Sources/CYFeedbackStyleTests"
        ),
        .testTarget(
            name: "CYAppDesignSystemTests",
            dependencies: ["CYAppDesignSystem", "CYFeedbackStyle"],
            path: "Sources/CYAppDesignSystemTests"
        ),
        .testTarget(
            name: "CYAppUITests",
            dependencies: ["CYAppUI", "CYAppCore", "CYFeedbackStyle"],
            path: "Sources/CYAppUITests"
        ),
        // 可运行 Demo（业务接入参考）
        .executableTarget(
            name: "ExampleApp",
            dependencies: ["CYAppCore", "CYFeedbackStyle", "CYAppDesignSystem", "CYAppUI"],
            path: "ExampleApp/Sources"
        ),
    ],
    swiftLanguageModes: [.v6]
)
