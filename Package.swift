// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChatKitSwift",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ChatKitSwift",
            targets: ["ChatKitSwift"],
        ),
        .executable(
            name: "ChatKitWidgetSnapshot",
            targets: ["ChatKitWidgetSnapshot"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ChatKitSwift",
            dependencies: [
                .product(name: "Textual", package: "textual"),
            ],
        ),
        .executableTarget(
            name: "ChatKitWidgetSnapshot",
            dependencies: ["ChatKitSwift"],
            path: "Tools/ChatKitWidgetSnapshot",
        ),
        .testTarget(
            name: "ChatKitSwiftTests",
            dependencies: ["ChatKitSwift"],
        ),
    ],
    swiftLanguageModes: [.v6],
)
