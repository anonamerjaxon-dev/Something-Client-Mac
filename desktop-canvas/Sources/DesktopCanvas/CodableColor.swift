import Foundation
import AppKit

public struct CodableColor: Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let black = CodableColor(red: 0, green: 0, blue: 0)
    public static let white = CodableColor(red: 1, green: 1, blue: 1)
    public static let clear = CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
}