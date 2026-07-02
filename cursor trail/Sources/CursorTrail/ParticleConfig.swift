import SwiftUI

/// Configuration for optional particle effect.
public struct ParticleConfig: Sendable {
    public let count: Int
    public let size: CGFloat
    public let color: Color

    public init(
        count: Int = 5,
        size: CGFloat = 4,
        color: Color = .white
    ) {
        self.count = max(count, 1)
        self.size = max(size, 1)
        self.color = color
    }
}
