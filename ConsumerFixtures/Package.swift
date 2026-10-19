// swift-tools-version: 6.0
import PackageDescription

let root = "SwiftUITemplate"
func product(_ name: String) -> Target.Dependency { .product(name: name, package: root) }
let scenarios = ["CoreOnly", "OfflinePersistence", "NetworkOnly", "DesignSystemConsumer", "CustomComposition"]
let package = Package(
    name: "ConsumerFixtures",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: scenarios.map { .library(name: $0, targets: [$0]) }
        + scenarios.map { .executable(name: $0 + "Proof", targets: [$0 + "Proof"]) },
    dependencies: [.package(name: "SwiftUITemplate", path: "..")],
    targets: [
        .target(name: "CoreOnly", dependencies: [product("CYAppCore")]),
        .target(name: "OfflinePersistence", dependencies: [product("CYAppCore"), product("CYAppPersistence")]),
        .target(name: "NetworkOnly", dependencies: [product("CYAppCore"), product("CYAppNetwork")]),
        .target(name: "DesignSystemConsumer", dependencies: [product("CYAppDesignSystem")]),
        .target(name: "CustomComposition", dependencies: [product("CYAppCore"), product("CYAppUI"), product("CYAppDesignSystem")]),
        .testTarget(name: "ConsumerTests", dependencies: ["CoreOnly", "OfflinePersistence", "NetworkOnly", "DesignSystemConsumer", "CustomComposition"])
    ] + scenarios.map { .executableTarget(name: $0 + "Proof", dependencies: [.target(name: $0)]) },
    swiftLanguageModes: [.v6]
)
