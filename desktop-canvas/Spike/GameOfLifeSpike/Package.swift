// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GameOfLifeSpike",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GameOfLifeSpike",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)