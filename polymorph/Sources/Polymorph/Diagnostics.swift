import AppKit
import CoreGraphics
import Foundation

public extension Polymorph {
    struct RegistryEntryInfo {
        public let identifier: String
        public let registered: Bool
        public let copyError: Int32
        public let size: CGSize
        public let hotspot: CGPoint
        public let frames: Int
        public let representationCount: Int

        public var line: String {
            "  \(identifier): registered=\(registered) copyErr=\(copyError) size=\(fmtSize) hotspot=(\(fmtHotspot)) frames=\(frames) reps=\(representationCount)"
        }

        private var fmtSize: String { String(format: "%.0fx%.0f", size.width, size.height) }
        private var fmtHotspot: String { String(format: "%.0f,%.0f", hotspot.x, hotspot.y) }
    }

    static func registryEntries(theme: CursorTheme) -> [RegistryEntryInfo] {
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        var result: [RegistryEntryInfo] = []
        for name in Set(theme.cursors.flatMap { $0.state.cgsNames }).sorted() {
            var size = CGSize.zero
            var hotspot = CGPoint.zero
            var frames: Int = 0
            var duration: CGFloat = 0
            var images: CFArray?
            let copyErr = name.withCString { bridge.copyRegisteredCursorImages(cid, $0, &size, &hotspot, &frames, &duration, &images) }
            result.append(RegistryEntryInfo(
                identifier: "[name] \(name)",
                registered: copyErr == .success,
                copyError: copyErr.rawValue,
                size: size,
                hotspot: hotspot,
                frames: frames,
                representationCount: images.map { CFArrayGetCount($0) } ?? -1
            ))
        }
        for slot in 0...24 {
            var images: CFArray?
            var size = CGSize.zero
            var hotspot = CGPoint.zero
            var frames: Int = 0
            var duration: CGFloat = 0
            let err = bridge.copyCoreCursorImages(cid, Int32(slot), &images, &size, &hotspot, &frames, &duration)
            guard err == .success else {
                continue
            }
            result.append(RegistryEntryInfo(
                identifier: "[slot \(slot)]",
                registered: true,
                copyError: 0,
                size: size,
                hotspot: hotspot,
                frames: frames,
                representationCount: images.map { CFArrayGetCount($0) } ?? -1
            ))
        }
        return result
    }

    static func currentSeed() -> Int32 {
        guard CGSBridge.isAvailable() else { return -1 }
        return CGSBridge.shared.currentCursorSeed()
    }

    static func runDiagnostics(theme: CursorTheme) throws -> [String] {
        var out: [String] = []
        func say(_ line: String) { out.append(line) }

        say("=== PRE-APPLY REGISTRY ===")
        registryEntries(theme: theme).forEach { say($0.line) }
        var baselineSeed = currentSeed()
        say("seed before apply: \(baselineSeed)")

        say("")
        say("=== APPLY ===")
        let report = try apply(theme: theme)
        say(report.summary)

        say("")
        say("=== POST-APPLY REGISTRY ===")
        registryEntries(theme: theme).forEach { say($0.line) }
        let afterSeed = currentSeed()
        say("seed after apply: \(afterSeed) changed=\(afterSeed != baselineSeed)")
        baselineSeed = afterSeed

        say("")
        say("=== LIVE MONITOR (15s) — hover this terminal, Safari, TextEdit, Desktop ===")
        var lastLocation = CGEvent(source: nil)?.location ?? .zero
        for tick in 1...15 {
            Thread.sleep(forTimeInterval: 1.0)
            let seed = currentSeed()
            let location = CGEvent(source: nil)?.location ?? .zero
            let moved = location != lastLocation
            lastLocation = location
            if seed != baselineSeed {
                say(String(format: "t=%02ds seed=%d  <-- SEED CHANGED%@", tick, seed, moved ? " (mouse moving)" : ""))
                baselineSeed = seed
            } else {
                say(String(format: "t=%02ds seed=%d%@ ", tick, seed, moved ? " (moving)" : " (idle)"))
            }
        }

        say("")
        say("=== FINAL REGISTRY ===")
        registryEntries(theme: theme).forEach { say($0.line) }

        try restore()
        say("")
        say("restored stock cursors")
        return out
    }
}

public extension Polymorph {
    struct OverlayAssets {
        public let cgImages: [CGImage]
        public let pointSize: CGSize
        public let hotspot: CGPoint
    }

    static func overlayAssets(for theme: CursorTheme, state: CursorState = .arrow) -> OverlayAssets? {
        guard let cursor = theme.cursors.first(where: { $0.state == state }) else { return nil }
        guard let images = try? ThemeImageLoader.cgImages(
            oneXURL: cursor.imageFile,
            retinaURL: cursor.retinaFile,
            pointSize: cursor.pointSize
        ) else { return nil }
        return OverlayAssets(cgImages: images, pointSize: cursor.pointSize, hotspot: cursor.hotspot)
    }
}
