import Foundation

public struct CanvasLayout: Codable {
    public var name: String
    public var canvases: [CanvasModel]

    public init(name: String, canvases: [CanvasModel]) {
        self.name = name
        self.canvases = canvases
    }

    public static func load(from url: URL) throws -> CanvasLayout {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CanvasLayout.self, from: data)
    }

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }
}