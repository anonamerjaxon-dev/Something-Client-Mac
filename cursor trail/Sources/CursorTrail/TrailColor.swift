import SwiftUI

/// Color configuration for the trail.
public enum TrailColor: Sendable {
    case solid(Color)
    case gradient(Color, Color)
    case rainbow
}
