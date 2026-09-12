import AppKit
import Foundation

public enum ThemeError: Error, CustomStringConvertible {
    case directoryNotFound(String)
    case missingArrow
    case unreadableImage(String)
    case invalidHotspotKey(String)
    case invalidSizeKey(String)
    case malformedThemeJSON(String)

    public var description: String {
        switch self {
        case .directoryNotFound(let path):
            return "Skin folder not found: \(path)"
        case .missingArrow:
            return "Every skin needs at least arrow.png (or .svg) — the default pointer is required"
        case .unreadableImage(let file):
            return "Could not read image: \(file)"
        case .invalidHotspotKey(let key):
            return "Unknown cursor state '\(key)' in theme.json hotspots"
        case .invalidSizeKey(let key):
            return "Unknown cursor state '\(key)' in theme.json sizes"
        case .malformedThemeJSON(let reason):
            return "theme.json is malformed: \(reason)"
        }
    }
}

public struct ResolvedCursor {
    public let state: CursorState
    public let imageFile: URL
    public let retinaFile: URL?
    public let pointSize: CGSize
    public let hotspot: CGPoint
}

public struct CursorTheme {
    public let name: String
    public let directory: URL
    public let cursors: [ResolvedCursor]

    public static func load(directory: URL) throws -> CursorTheme {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ThemeError.directoryNotFound(directory.path)
        }

        let metaFile = directory.appendingPathComponent("theme.json")
        var name = directory.lastPathComponent
        var hotspotOverrides: [String: [CGFloat]] = [:]
        var sizeOverrides: [String: CGFloat] = [:]

        if FileManager.default.fileExists(atPath: metaFile.path) {
            let raw: Any
            do {
                raw = try JSONSerialization.jsonObject(with: Data(contentsOf: metaFile))
            } catch {
                throw ThemeError.malformedThemeJSON(error.localizedDescription)
            }
            guard let dict = raw as? [String: Any] else {
                throw ThemeError.malformedThemeJSON("root must be an object")
            }
            if let n = dict["name"] as? String { name = n }
            if let hotspots = dict["hotspots"] as? [String: [CGFloat]] { hotspotOverrides = hotspots }
            if let sizes = dict["sizes"] as? [String: CGFloat] { sizeOverrides = sizes }
        }

        for (key, value) in hotspotOverrides {
            guard CursorState(rawValue: key) != nil else { throw ThemeError.invalidHotspotKey(key) }
            guard value.count == 2 else { throw ThemeError.malformedThemeJSON("hotspot for '\(key)' must be [x, y]") }
        }
        for (key, _) in sizeOverrides {
            guard CursorState(rawValue: key) != nil else { throw ThemeError.invalidSizeKey(key) }
        }

        var cursors: [ResolvedCursor] = []
        for state in CursorState.allCases where Self.findImage(for: state, in: directory) != nil {
            let files = Self.findImage(for: state, in: directory)!
            let pointSize = try Self.resolvePointSize(for: state, override: sizeOverrides[state.rawValue], oneXURL: files.oneX)
            let hotspot = try Self.resolveHotspot(for: state, override: hotspotOverrides[state.rawValue].map { CGPoint(x: $0[0], y: $0[1]) }, pointSize: pointSize)
            cursors.append(ResolvedCursor(state: state, imageFile: files.oneX, retinaFile: files.twoX, pointSize: pointSize, hotspot: hotspot))
        }

        guard cursors.contains(where: { $0.state == .arrow }) else {
            throw ThemeError.missingArrow
        }

        return CursorTheme(name: name, directory: directory, cursors: cursors)
    }

    private static func findImage(for state: CursorState, in directory: URL) -> (oneX: URL, twoX: URL?)? {
        for ext in CursorState.fileExtensions {
            let url = directory.appendingPathComponent("\(state.rawValue).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                var twoX: URL?
                for twoExt in CursorState.fileExtensions {
                    let candidate = directory.appendingPathComponent("\(state.rawValue)@2x.\(twoExt)")
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        twoX = candidate
                        break
                    }
                }
                return (url, twoX)
            }
        }
        return nil
    }

    private static func resolvePointSize(for state: CursorState, override: CGFloat?, oneXURL: URL) throws -> CGSize {
        if let override = override {
            return CGSize(width: override, height: override)
        }
        if let system = state.systemCursor?.image.size, system.width > 0 {
            return system
        }
        guard let image = NSImage(contentsOf: oneXURL) else {
            throw ThemeError.unreadableImage(oneXURL.path)
        }
        let size = image.size
        return CGSize(width: min(size.width, 32), height: min(size.height, 32))
    }

    private static func resolveHotspot(for state: CursorState, override: CGPoint?, pointSize: CGSize) throws -> CGPoint {
        if let override = override {
            return override
        }
        if let system = state.systemCursor?.hotSpot {
            return system
        }
        return CGPoint(x: pointSize.width / 2, y: pointSize.height / 2)
    }
}
