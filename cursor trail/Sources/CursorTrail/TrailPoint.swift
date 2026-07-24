import Foundation
import CoreGraphics
import QuartzCore

public struct TrailPoint {
    public let position: CGPoint
    public let timestamp: CFTimeInterval

    public init(position: CGPoint, timestamp: CFTimeInterval = CACurrentMediaTime()) {
        self.position = position
        self.timestamp = timestamp
    }
}