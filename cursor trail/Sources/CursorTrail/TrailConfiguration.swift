import SwiftUI

/// Complete configuration for a cursor trail.
public struct TrailConfiguration: Sendable {
    public var color: TrailColor
    public var thickness: CGFloat
    public var length: Int
    public var fadeSpeed: Double
    public var rainbowSpeed: Double
    public var diminishing: Bool
    public var diminishingIntensity: Double
    public var style: TrailStyle
    public var speedMode: SpeedMode
    public var opacity: Double
    public var glow: GlowConfig?

    public init(
        color: TrailColor = .rainbow,
        thickness: CGFloat = 12,
        length: Int = 10,
        fadeSpeed: Double = 1.0,
        rainbowSpeed: Double = 5.0,
        diminishing: Bool = true,
        diminishingIntensity: Double = 0.7,
        style: TrailStyle = .ribbon,
        speedMode: SpeedMode = .adaptive,
        opacity: Double = 0.8,
        glow: GlowConfig? = nil
    ) {
        self.color = color
        self.thickness = max(thickness, 1)
        self.length = max(length, 10)
        self.fadeSpeed = max(fadeSpeed, 0.1)
        self.rainbowSpeed = max(rainbowSpeed, 0.1)
        self.diminishing = diminishing
        self.diminishingIntensity = max(min(diminishingIntensity, 1.0), 0.0)
        self.style = style
        self.speedMode = speedMode
        self.opacity = max(min(opacity, 1.0), 0.0)
        self.glow = glow
    }

    /// The minimum width factor for the trail tail, accounting for diminishing settings.
    /// - Parameter forLine: `true` for line style (tapers to 20%), `false` for ribbon (tapers to 0%).
    func diminishingMin(forLine: Bool) -> CGFloat {
        if !diminishing { return forLine ? 0.2 : 1.0 }
        let factor = max(1.0 - diminishingIntensity, 0.0)
        return forLine ? 0.2 * factor : factor
    }
}