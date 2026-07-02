import Foundation
import CoreGraphics
import QuartzCore

/// Represents a single point in the cursor trail.
public struct TrailPoint {
    public let position: CGPoint
    public let timestamp: CFTimeInterval
    public let velocity: CGFloat // pixels per second

    public init(position: CGPoint, timestamp: CFTimeInterval = CACurrentMediaTime(), velocity: CGFloat = 0) {
        self.position = position
        self.timestamp = timestamp
        self.velocity = velocity
    }
}
