// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowLevelTest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WindowLevelTest",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)