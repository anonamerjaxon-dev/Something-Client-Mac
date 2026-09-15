import Foundation
import QuartzCore

public struct TrailFrame {
    public let frame: NSRect
    public let timestamp: CFTimeInterval

    public init(frame: NSRect, timestamp: CFTimeInterval = CACurrentMediaTime()) {
        self.frame = frame
        self.timestamp = timestamp
    }
}