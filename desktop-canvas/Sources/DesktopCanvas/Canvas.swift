import Foundation
import CoreGraphics

public enum CanvasType: String, Codable, CaseIterable {
    case gameOfLife
    case video
}

public struct GameOfLifeConfig: Codable {
    public var ruleSet: RuleSet
    public var cellSize: Int
    public var aliveColor: CodableColor
    public var deadColor: CodableColor
    public var marginColor: CodableColor
    public var generationsPerSecond: Double
    public var gridState: [[Bool]]?
    public var paused: Bool

    public init(
        ruleSet: RuleSet = .conway,
        cellSize: Int = 8,
        aliveColor: CodableColor = CodableColor(red: 0.2, green: 0.9, blue: 0.3),
        deadColor: CodableColor = CodableColor(red: 0.05, green: 0.05, blue: 0.05),
        marginColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0),
        generationsPerSecond: Double = 30,
        gridState: [[Bool]]? = nil,
        paused: Bool = false
    ) {
        self.ruleSet = ruleSet
        self.cellSize = cellSize
        self.aliveColor = aliveColor
        self.deadColor = deadColor
        self.marginColor = marginColor
        self.generationsPerSecond = generationsPerSecond
        self.gridState = gridState
        self.paused = paused
    }

    public static let `default` = GameOfLifeConfig()
}

public struct VideoConfig: Codable {
    public var videoURL: URL
    public var volume: Double
    public var loop: Bool
    public var naturalSize: CGSize?

    public init(
        videoURL: URL = URL(fileURLWithPath: ""),
        volume: Double = 0.0,
        loop: Bool = true,
        naturalSize: CGSize? = nil
    ) {
        self.videoURL = videoURL
        self.volume = volume
        self.loop = loop
        self.naturalSize = naturalSize
    }

    public static let `default` = VideoConfig()
}

public struct CanvasModel: Identifiable, Equatable {
    public var id: UUID
    public var type: CanvasType
    public var frame: CGRect
    public var gameOfLifeConfig: GameOfLifeConfig?
    public var videoConfig: VideoConfig?

    public static func == (lhs: CanvasModel, rhs: CanvasModel) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: UUID = UUID(),
        type: CanvasType,
        frame: CGRect,
        gameOfLifeConfig: GameOfLifeConfig? = nil,
        videoConfig: VideoConfig? = nil
    ) {
        self.id = id
        self.type = type
        self.frame = CGRect(
            origin: CGPoint(x: frame.origin.x, y: frame.origin.y),
            size: CGSize(
                width: max(frame.size.width, 32),
                height: max(frame.size.height, 32)
            )
        )
        self.gameOfLifeConfig = gameOfLifeConfig
        self.videoConfig = videoConfig
    }
}

extension CanvasModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, frame, gameOfLifeConfig, videoConfig
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(CanvasType.self, forKey: .type)
        gameOfLifeConfig = try container.decodeIfPresent(GameOfLifeConfig.self, forKey: .gameOfLifeConfig)
        videoConfig = try container.decodeIfPresent(VideoConfig.self, forKey: .videoConfig)

        let rectValues = try container.decode([Double].self, forKey: .frame)
        guard rectValues.count == 4 else {
            throw DecodingError.dataCorruptedError(
                forKey: .frame,
                in: container,
                debugDescription: "CGRect requires exactly 4 values"
            )
        }
        frame = CGRect(
            origin: CGPoint(x: rectValues[0], y: rectValues[1]),
            size: CGSize(
                width: max(rectValues[2], 32),
                height: max(rectValues[3], 32)
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(gameOfLifeConfig, forKey: .gameOfLifeConfig)
        try container.encodeIfPresent(videoConfig, forKey: .videoConfig)
        try container.encode(
            [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height],
            forKey: .frame
        )
    }
}