# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CursorTrail** is a Swift library that draws a smooth, animated trail behind the mouse cursor on macOS. It renders on a transparent overlay window at `.screenSaver` window level, floating above all content. The library uses a builder pattern for configuration and targets macOS 13.0+.

## Key Commands

```bash
# Build the entire package
swift build

# Run all tests
swift test

# Run the TestRunner executable (minimal self-hosting test harness)
swift run TestRunner

# Run the full SwiftUI demo app with live controls
swift run CursorTrailDemo
```

## Architecture

### Core Entry Point
- **`CursorTrail.swift`** — Main class with builder pattern (`color()`, `thickness()`, `style()`, etc.). Creates the overlay window, runs a 60Hz Timer loop that polls `NSEvent.mouseLocation`, appends points to a ring buffer, fades the trail when the mouse stops, and updates the window each frame. Static `current` property holds a singleton reference.

### Window & Rendering
- **`TrailWindow.swift`** — Wraps an `NSWindow` configured as transparent, borderless, `.screenSaver`-level overlay with `.canJoinAllSpaces` and `.ignoresMouseEvents = true` (clicks pass through). Hosts a SwiftUI `TrailContentView` backed by an `NSHostingView` with a `Canvas` for rendering.
- **`TrailRenderer.swift`** — Renders the trail onto a `GraphicsContext`. Supports `.line` (multi-pass stroked polyline for depth) and `.ribbon` (filled Catmull-Rom spline with perpendicular normals for width). Handles glow (blurred shadow via `.blur` filter), particles, color gradients, and rainbow cycling.

### Data Structures
- **`RingBuffer.swift`** — Fixed-capacity circular buffer for trail points. O(1) append/removeFirst. Used by `CursorTrail` to store the sequence of mouse positions.
- **`TrailPoint.swift`** — Holds `position: CGPoint`, `timestamp: CFTimeInterval`, and `velocity: CGFloat` (pixels per second).

### Configuration
- **`TrailConfiguration.swift`** — Struct holding all mutable trail parameters: style, color, thickness, length, fade speed, rainbow speed, diminishing, speed mode, glow, and particles.
- **`TrailColor.swift`** — Enum: `.solid(Color)`, `.gradient(Color, Color)`, `.rainbow`.
- **`TrailStyle.swift`** — Enum: `.line` (multi-pass stroked path) or `.ribbon` (filled spline).
- **`SpeedMode.swift`** — Enum: `.fixed` or `.adaptive` (width scales with mouse velocity).
- **`GlowConfig.swift`** — Optional glow: radius, intensity (0-1), optional custom color.
- **`ParticleConfig.swift`** — Optional particles: count, size, color.

### Demo & Testing
- **`Examples/CursorTrailDemo/`** — SwiftUI app with live controls for all configuration parameters (style, color picker, sliders for length/fade/thickness/rainbow/diminishing). Use this to visually test changes.
- **`Tests/CursorTrailTests/`** — Self-hosted test harness (custom `XCTAssert*` functions, not XCTest). Tests `RingBuffer` (empty, append, overwrite, clear) and `TrailConfiguration` (defaults, custom values).
- **`Tests/TestRunner/`** — Placeholder test runner that verifies the module loads.

### Important Notes
- The tests use a custom assertion harness, not XCTest. Do not try to add XCTest-based tests without updating the harness.
- The `TrailRenderer` uses `NSScreen.main?.frame.height` coordinate flipping for macOS screen coordinates.
- Mouse movement detection uses a squared-distance threshold of 0.25 (0.5px) to avoid jitter.
- The `.rainbow` case in `TrailColor` returns an array of 6 discrete colors, not a continuous spectrum. Rainbow cycling is handled separately in `TrailRenderer.colorForTrail()` via HSL hue rotation.
