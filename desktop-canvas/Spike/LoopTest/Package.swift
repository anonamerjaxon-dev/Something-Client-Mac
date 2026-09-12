// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LoopTest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LoopTest",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)