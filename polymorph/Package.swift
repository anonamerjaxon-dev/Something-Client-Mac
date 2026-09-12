// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Polymorph",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Polymorph",
            targets: ["Polymorph"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Polymorph",
            dependencies: [],
            path: "Sources/Polymorph",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["Polymorph"],
            path: "Tests/TestRunner"
        ),
        .executableTarget(
            name: "PolymorphDemo",
            dependencies: ["Polymorph"],
            path: "Examples/PolymorphDemo"
        ),
        .executableTarget(
            name: "PolymorphCLI",
            dependencies: ["Polymorph"],
            path: "Sources/PolymorphCLI"
        ),
        .executableTarget(
            name: "PolymorphAgent",
            dependencies: ["Polymorph"],
            path: "Examples/PolymorphAgent"
        )
    ]
)
