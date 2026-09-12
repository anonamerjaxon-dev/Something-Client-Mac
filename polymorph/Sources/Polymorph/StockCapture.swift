import AppKit
import CoreGraphics
import Foundation

public extension Polymorph {
    struct CapturedCursor {
        public let name: String
        public let pointSize: CGSize
        public let hotspot: CGPoint
        public let pngFiles: [URL]
    }

    static var stockCaptureDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Polymorph/SystemDefault", isDirectory: true)
    }

    static func hasStockCapture() -> Bool {
        FileManager.default.fileExists(atPath: stockCaptureDirectory.appendingPathComponent("manifest.json").path)
    }

    static func captureStockCursors() throws -> Int {
        guard CGSBridge.isAvailable() else { throw PolymorphError.bridgeUnavailable }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        let dir = stockCaptureDirectory
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var manifest: [[String: Any]] = []
        var names = Set(CursorState.allCases.flatMap { $0.cgsNames })
        names.formUnion(["com.apple.coregraphics.ArrowS", "com.apple.coregraphics.IBeamS"])

        for name in names.sorted() {
            var size = CGSize.zero
            var hotspot = CGPoint.zero
            var frames: Int = 0
            var duration: CGFloat = 0
            var images: CFArray?
            let err = name.withCString { bridge.copyRegisteredCursorImages(cid, $0, &size, &hotspot, &frames, &duration, &images) }
            guard err == .success, let array = images, CFArrayGetCount(array) > 0 else { continue }

            var files: [String] = []
            for i in 0..<CFArrayGetCount(array) {
                let value = CFArrayGetValueAtIndex(array, i)
                let image = unsafeBitCast(value, to: CGImage.self)
                let rep = NSBitmapImageRep(cgImage: image)
                guard let data = rep.representation(using: .png, properties: [:]) else { continue }
                let fileURL = dir.appendingPathComponent("\(name.replacingOccurrences(of: "/", with: "_"))-\(i).png")
                try data.write(to: fileURL)
                files.append(fileURL.lastPathComponent)
            }
            guard !files.isEmpty else { continue }
            manifest.append([
                "name": name,
                "pointSize": [Double(size.width), Double(size.height)],
                "hotspot": [Double(hotspot.x), Double(hotspot.y)],
                "files": files
            ])
        }

        let data = try JSONSerialization.data(withJSONObject: ["cursors": manifest])
        try data.write(to: dir.appendingPathComponent("manifest.json"))
        return manifest.count
    }

    internal static func loadCapturedStockSet() -> [(name: String, pointSize: CGSize, hotspot: CGPoint, images: [CGImage])] {
        let dir = stockCaptureDirectory
        let manifestURL = dir.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return [] }
        guard let data = try? Data(contentsOf: manifestURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["cursors"] as? [[String: Any]] else { return [] }

        var result: [(String, CGSize, CGPoint, [CGImage])] = []
        for entry in entries {
            guard let name = entry["name"] as? String,
                  let sizeArray = entry["pointSize"] as? [Double], sizeArray.count == 2,
                  let hotArray = entry["hotspot"] as? [Double], hotArray.count == 2,
                  let files = entry["files"] as? [String] else { continue }
            let pointSize = CGSize(width: sizeArray[0], height: sizeArray[1])
            let hotspot = CGPoint(x: hotArray[0], y: hotArray[1])

            var cgImages: [CGImage] = []
            for file in files {
                guard let image = NSImage(contentsOf: dir.appendingPathComponent(file)) else { continue }
                guard let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: max(1, Int(pointSize.width * 2)),
                    pixelsHigh: max(1, Int(pointSize.height * 2)),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
                ) else { continue }
                rep.size = pointSize
                NSGraphicsContext.saveGraphicsState()
                guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
                    NSGraphicsContext.restoreGraphicsState()
                    continue
                }
                NSGraphicsContext.current = ctx
                image.draw(in: NSRect(origin: .zero, size: pointSize))
                ctx.flushGraphics()
                NSGraphicsContext.restoreGraphicsState()
                guard let cgImage = rep.cgImage else { continue }
                cgImages.append(cgImage)
            }
            guard !cgImages.isEmpty else { continue }
            result.append((name, pointSize, hotspot, cgImages))
        }
        return result
    }

    internal static func registerStockSet(bridge: CGSBridge, cid: Int32, instantly: Bool, activate: Bool) -> Int {        var count = 0
        for captured in loadCapturedStockSet() {
            var seed: Int32 = 0
            let err = captured.name.withCString { cName in
                bridge.registerCursorWithImages(cid, cName, true, instantly, captured.pointSize, captured.hotspot, 1, 0, captured.images as CFArray, &seed)
            }
            guard err == .success else { continue }
            count += 1
            if activate {
                var activateSeed: Int32 = 0
                _ = captured.name.withCString { bridge.setRegisteredCursor(cid, $0, &activateSeed) }
                if captured.name.hasPrefix("com.apple.cursor.") {
                    if let slot = Int32(captured.name.dropFirst("com.apple.cursor.".count)) {
                        _ = bridge.setCoreCursor(cid, slot)
                    }
                }
            }
        }
        return count
    }

    @discardableResult
    static func restoreFromStockCapture() throws -> Int {
        guard CGSBridge.isAvailable() else { throw PolymorphError.bridgeUnavailable }
        guard !loadCapturedStockSet().isEmpty else {
            throw PolymorphError.noStockCapture
        }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        let restoredCount = registerStockSet(bridge: bridge, cid: cid, instantly: true, activate: true)
        try? nudgeCursorScale()
        return restoredCount
    }
}
