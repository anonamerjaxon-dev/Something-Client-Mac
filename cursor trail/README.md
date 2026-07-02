# CursorTrail

A Swift library that draws a smooth, animated trail behind the mouse cursor on macOS. The trail renders on a transparent overlay window at `.screenSaver` window level, floating above all content and passing clicks through.

## Requirements

- macOS 13.0+
- Swift 5.9+

## Quick Start

```swift
import CursorTrail

// Start with all defaults
CursorTrail().start()

// Stop it
CursorTrail.current?.stop()
```

## Configuration

Use the builder pattern to customize before calling `.start()`:

```swift
CursorTrail()
    .color(.gradient(.cyan, .purple))
    .thickness(14)
    .length(80)
    .style(.ribbon)
    .fadeSpeed(1.0)
    .rainbowSpeed(5.0)
    .diminishing(true)
    .diminishingIntensity(0.7)
    .opacity(0.8)
    .speed(.adaptive)
    .glow(GlowConfig(radius: 8, intensity: 0.5))
    .start()
```

## Defaults

| Parameter | Default | Value |
|---|---|---|
| `color` | `.rainbow` | Cycling HSL spectrum |
| `style` | `.ribbon` | Filled Catmull-Rom spline |
| `thickness` | `12` | Points |
| `length` | `10` | Buffer capacity (min enforced: 10) |
| `fadeSpeed` | `1.0` | Points removed per frame when mouse stops |
| `rainbowSpeed` | `5.0` | Multiplier for color cycling |
| `diminishing` | `true` | Tail tapers toward cursor head |
| `diminishingIntensity` | `0.7` | 0.0 = uniform width, 1.0 = maximum taper |
| `opacity` | `0.8` | Overall trail transparency (0.0-1.0) |
| `speed` | `.adaptive` | Width scales with mouse velocity |
| `glow` | `nil` | No glow by default |
| `particles` | `nil` | No particles by default |

## API Reference

### `TrailColor`

```swift
public enum TrailColor {
    case solid(Color)       // Single color, e.g. .solid(.cyan)
    case gradient(Color, Color) // Two-color blend, e.g. .gradient(.red, .blue)
    case rainbow            // HSL hue cycling
}
```

### `TrailStyle`

```swift
public enum TrailStyle {
    case line    // Multi-pass stroked polyline (4 passes for depth)
    case ribbon  // Filled spline with perpendicular normals
}
```

### `SpeedMode`

```swift
public enum SpeedMode {
    case fixed     // Constant width regardless of movement
    case adaptive  // Width scales with mouse velocity
}
```

### `GlowConfig`

```swift
GlowConfig(radius: 8, intensity: 0.5, color: nil)
// radius: blur spread in points
// intensity: 0.0 (invisible) to 1.0 (full)
// color: nil uses the trail's current color
```

### `ParticleConfig`

```swift
ParticleConfig(count: 5, size: 4, color: .white)
// count: number of particles placed along the trail
// size: diameter in points
// color: particle fill color
```

## What Not To Do

- **Don't call `.start()` multiple times.** Each call creates a new overlay window. Call `.stop()` first or check `CursorTrail.current`.
- **Don't reuse the same `CursorTrail` builder instance.** The builder pattern creates a snapshot of configuration at `.start()` time. Chain `.start()` immediately after your config calls.
- **Don't set `length` below 10.** The minimum is enforced, but the trail will look choppy with fewer than ~20 points.
- **Don't set `opacity` to 0.** The trail won't be visible. This is a common mistake when the slider defaults are misread — opacity is 0.0-1.0, not percentage.
- **Don't expect multi-monitor support.** The trail covers only the main display.
- **Don't expect it to work in full-screen games.** Apps using `CGDisplayCapture` (games, video players) block all external overlay drawing.
- **Don't set `diminishingIntensity` above 1.0 or below 0.0.** Values are clamped, but extreme values produce a flat or nearly invisible tail.
- **Don't mix `.solid` color with `.rainbowSpeed`.** Rainbow speed only has an effect when `color` is `.rainbow`. Setting it on a solid color is dead work.
- **Don't forget to call `.stop()` in app cleanup.** The deinit handles it, but if you hold a strong reference to the builder, the overlay stays alive.

## Recommended Presets

### Subtle
```swift
CursorTrail()
    .color(.solid(.gray))
    .thickness(4)
    .length(50)
    .style(.line)
    .diminishing(true)
    .diminishingIntensity(0.3)
    .opacity(0.5)
    .start()
```

### Bold
```swift
CursorTrail()
    .color(.gradient(.cyan, .magenta))
    .thickness(20)
    .length(150)
    .style(.ribbon)
    .diminishing(false)
    .glow(GlowConfig(radius: 15, intensity: 0.7))
    .opacity(0.9)
    .start()
```

### Minimal
```swift
CursorTrail()
    .color(.solid(.white))
    .thickness(2)
    .length(20)
    .style(.line)
    .diminishing(true)
    .diminishingIntensity(0.5)
    .opacity(0.6)
    .start()
```

## Architecture

| Component | Role |
|---|---|
| `CursorTrail` | Main class, builder pattern, 60 Hz Timer loop |
| `TrailWindow` | Transparent `NSWindow` at `.screenSaver` level |
| `TrailModel` | `ObservableObject` holding `@Published trailPoints` |
| `TrailContentView` | SwiftUI `Canvas` view that renders via `TrailRenderer` |
| `TrailRenderer` | Draws line/ribbon/glow/particles onto `GraphicsContext` |
| `RingBuffer` | Fixed-capacity circular buffer for O(1) point storage |
| `TrailPoint` | Position, timestamp, velocity |

The window uses `.ignoresMouseEvents = true` so clicks pass through to content below. `.canJoinAllSpaces` ensures visibility across all Desktops/Spaces.

## Demo App

The included SwiftUI demo (`CursorTrailDemo`) provides live controls for all parameters:

```bash
swift build
open CursorTrail.app
# or
swift run CursorTrailDemo
```

## License

MIT
