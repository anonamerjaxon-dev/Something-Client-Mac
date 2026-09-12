// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PermissionsTest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PermissionsTest",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)