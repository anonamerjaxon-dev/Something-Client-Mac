// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CompositingTest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CompositingTest",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)