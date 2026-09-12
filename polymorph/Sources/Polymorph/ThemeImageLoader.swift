import AppKit
import CoreGraphics

enum ThemeImageError: Error, CustomStringConvertible {
    case unreadable(String)
    case renderFailed(String)

    var description: String {
        switch self {
        case .unreadable(let path):
            return "Could not decode image: \(path) (supported: png, svg, jpg, tiff)"
        case .renderFailed(let path):
            return "Could not rasterize: \(path)"
        }
    }
}

enum ThemeImageLoader {
    static func cgImages(oneXURL: URL, retinaURL: URL?, pointSize: CGSize, scales: [CGFloat] = [1.0, 2.0]) throws -> [CGImage] {
        let source = NSImage(contentsOf: oneXURL)
        let retinaSource = retinaURL.flatMap { NSImage(contentsOf: $0) }
        guard source != nil || retinaSource != nil else {
            throw ThemeImageError.unreadable(oneXURL.path)
        }

        var result: [CGImage] = []
        for scale in scales {
            let chosen: NSImage?
            if scale > 1, retinaSource != nil {
                chosen = retinaSource
            } else {
                chosen = source
            }
            guard let image = chosen else {
                throw ThemeImageError.unreadable(retinaURL?.path ?? oneXURL.path)
            }
            let pixelSize = CGSize(
                width: max(1, round(pointSize.width * scale)),
                height: max(1, round(pointSize.height * scale))
            )
            guard let cg = rasterize(image: image, pixelSize: pixelSize) else {
                throw ThemeImageError.renderFailed(oneXURL.path)
            }
            result.append(cg)
        }
        return result
    }

    private static func rasterize(image: NSImage, pixelSize: CGSize) -> CGImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = pixelSize

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        let fitScale = min(pixelSize.width / sourceSize.width, pixelSize.height / sourceSize.height)
        let drawSize = NSSize(
            width: sourceSize.width * fitScale,
            height: sourceSize.height * fitScale
        )
        let drawOrigin = NSPoint(
            x: (pixelSize.width - drawSize.width) / 2,
            y: (pixelSize.height - drawSize.height) / 2
        )
        image.draw(
            in: NSRect(origin: drawOrigin, size: drawSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .sourceOver,
            fraction: 1.0
        )
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return rep.cgImage
    }
}
