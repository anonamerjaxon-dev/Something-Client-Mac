import SwiftUI

public enum TrailColor: Sendable {
    case solid(Color)
    case gradient(Color, Color)
    case rainbow
}