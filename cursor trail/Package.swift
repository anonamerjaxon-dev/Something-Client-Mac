// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CursorTrail",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CursorTrail",
            targets: ["CursorTrail"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CursorTrail",
            dependencies: [],
            path: "Sources/CursorTrail",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "CursorTrailTests",
            dependencies: ["CursorTrail"],
            path: "Tests/CursorTrailTests"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["CursorTrail"],
            path: "Tests/TestRunner"
        ),
        .executableTarget(
            name: "CursorTrailDemo",
            dependencies: ["CursorTrail"],
            path: "Examples/CursorTrailDemo"
        )
    ]
)
