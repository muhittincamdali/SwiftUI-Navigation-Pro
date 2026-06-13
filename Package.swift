// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftUINavigationPro",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftUINavigationPro", targets: ["SwiftUINavigationPro"]),
    ],
    targets: [
        .target(
            name: "SwiftUINavigationPro",
            path: "Sources/SwiftUINavigationPro",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftUINavigationProTests",
            dependencies: ["SwiftUINavigationPro"]
        )
    ]
)
