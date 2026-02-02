// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUINavigationPro",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SwiftUINavigationPro",
            targets: ["SwiftUINavigationPro"]
        )
    ],
    targets: [
        .target(
            name: "SwiftUINavigationPro",
            path: "Sources/SwiftUINavigationPro"
        ),
        .testTarget(
            name: "SwiftUINavigationProTests",
            dependencies: ["SwiftUINavigationPro"],
            path: "Tests/SwiftUINavigationProTests"
        )
    ]
)
