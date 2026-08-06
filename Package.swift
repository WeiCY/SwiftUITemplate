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
        .library(name: "CYAppNetwork", targets: ["CYAppNetwork"]),
        .library(name: "CYAppImage", targets: ["CYAppImage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.12.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.11.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.3.2"),
    ],
    targets: [
        // Layer 0: 纯逻辑层，零第三方重依赖（仅 Factory DI）
        .target(
            name: "CYAppCore",
            dependencies: [
                .product(name: "FactoryKit", package: "Factory"),
            ],
            path: "Sources/CYAppCore",
            resources: [.process("Resources")]
        ),
        // Layer 0: 网络实现层（Alamofire 封装）
        .target(
            name: "CYAppNetwork",
            dependencies: [
                "CYAppCore",
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            path: "Sources/CYAppNetwork"
        ),
        // Layer 0: 图片加载实现层（Kingfisher 封装）
        .target(
            name: "CYAppImage",
            dependencies: [
                "CYAppCore",
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "Sources/CYAppImage"
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
        .testTarget(
            name: "CYAppNetworkTests",
            dependencies: ["CYAppNetwork", "CYAppCore"],
            path: "Sources/CYAppNetworkTests"
        ),
        // 可运行 Demo（业务接入参考）
        .executableTarget(
            name: "ExampleApp",
            dependencies: ["CYAppCore", "CYAppNetwork", "CYAppImage", "CYFeedbackStyle", "CYAppDesignSystem", "CYAppUI"],
            path: "ExampleApp/Sources"
        ),
    ],
    swiftLanguageModes: [.v6]
)
