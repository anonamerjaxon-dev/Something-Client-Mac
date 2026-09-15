import SwiftUI

public struct GlowConfig: Sendable {
    public let radius: CGFloat
    public let intensity: Double
    public let color: Color?

    public init(radius: CGFloat = 8, intensity: Double = 0.5, color: Color? = nil) {
        self.radius = radius
        self.intensity = min(max(intensity, 0), 1)
        self.color = color
    }
}