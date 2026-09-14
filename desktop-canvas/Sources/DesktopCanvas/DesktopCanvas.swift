import AppKit

public enum ApplyResult {
    case ok
    case warning(String)
    case error(String)
}

public struct PresetInfo: Identifiable {
    public var id: String { name }
    public let name: String
    public let canvasCount: Int
    public let modifiedAt: Date
}

public final class DesktopCanvas {
    public static let shared = DesktopCanvas()

    private var screenManager: ScreenManager?

    private init() {}

    @discardableResult
    public func apply(layout: CanvasLayout) -> ApplyResult {
        let overlaps = OverlapResolver.detectOverlaps(in: layout.canvases)
        if !overlaps.isEmpty {
            let ids = overlaps.map { "\($0.0) & \($0.1)" }.joined(separator: ", ")
            return .error("Layout contains \(overlaps.count) overlapping canvas(es): \(ids). Separate or remove overlapping canvases before applying.")
        }

        let totalCells = layout.canvases.reduce(0) { count, canvas in
            guard canvas.type == .gameOfLife, let config = canvas.gameOfLifeConfig else {
                return count
            }
            let cols = Int(floor(canvas.frame.width / CGFloat(config.cellSize)))
            let rows = Int(floor(canvas.frame.height / CGFloat(config.cellSize)))
            return count + (cols * rows)
        }

        stop()

        let manager = ScreenManager()
        manager.applyEmbedded(layout: layout)
        self.screenManager = manager

        Self.saveLastUsedPreset(layout)

        if totalCells > 10_000_000 {
            return .warning("Total Game of Life cells (\(totalCells)) exceeds recommended limit of 10M. Performance may degrade.")
        }
        return .ok
    }

    public func stop() {
        screenManager?.stop()
        screenManager = nil
    }

    public func refresh(with layout: CanvasLayout? = nil) {
        screenManager?.refresh(with: layout)
    }

    public func withGoLProvider(for canvasID: UUID, body: (GameOfLifeProvider) -> Void) {
        guard let provider = screenManager?.provider(for: canvasID, as: GameOfLifeProvider.self) else {
            return
        }
        body(provider)
    }

    public func savePreset(_ layout: CanvasLayout, named name: String) throws {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        try layout.save(to: url)
    }

    public func loadPreset(named name: String) throws -> CanvasLayout {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        return try CanvasLayout.load(from: url)
    }

    public func deletePreset(named name: String) throws {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        try FileManager.default.removeItem(at: url)
    }

    public func listPresets() -> [String] {
        let dir = Self.presetsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        return contents
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "_last_used.json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    public func listPresetsWithMetadata() -> [PresetInfo] {
        let dir = Self.presetsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "_last_used.json" }
            .compactMap { url in
                let name = url.deletingPathExtension().lastPathComponent
                let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let layout = try? CanvasLayout.load(from: url)
                let count = layout?.canvases.count ?? 0
                return PresetInfo(name: name, canvasCount: count, modifiedAt: modifiedAt)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public static func presetsDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("DesktopCanvas/presets", isDirectory: true)
    }

    public static func lastUsedPresetURL() -> URL {
        presetsDirectory().appendingPathComponent("_last_used.json")
    }

    public static func saveLastUsedPreset(_ layout: CanvasLayout) {
        let dir = presetsDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? layout.save(to: lastUsedPresetURL())
    }

    public static func loadLastUsedPreset() -> CanvasLayout? {
        try? CanvasLayout.load(from: lastUsedPresetURL())
    }
}