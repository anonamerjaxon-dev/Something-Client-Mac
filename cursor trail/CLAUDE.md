# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CursorTrail** is a Swift library that draws a smooth, animated trail behind the mouse cursor on macOS. It renders on a transparent overlay window at `.screenSaver` window level, floating above all content. The library uses a builder pattern for configuration and targets macOS 13.0+.

## Key Commands

```bash
swift build
swift test
swift run TestRunner
swift run CursorTrailDemo
```

## Architecture

### Core Entry Point
- **`CursorTrail.swift`** — Main class with builder pattern (`color()`, `thickness()`, `style()`, `speed()`, etc.). Creates the overlay window, runs a CVDisplayLink render loop synced to display refresh, polls `NSEvent.mouseLocation`, appends points to a ring buffer, fades the trail when idle, and updates the window each frame. Static `current` singleton.

### Window & Rendering
- **`TrailWindow.swift`** — Transparent, borderless `NSWindow` at `.screenSaver` level with `.canJoinAllSpaces`, `.fullScreenAuxiliary`, and `.ignoresMouseEvents = true` (clicks pass through). Hosts a SwiftUI `Canvas` in an `NSHostingView`.
- **`TrailRenderer.swift`** — Draws the trail into a `GraphicsContext`. Supports `.line` (multi-pass stroked polyline) and `.ribbon` (filled Catmull-Rom spline with perpendicular normals). Handles glow via `.blur` filter, color gradients, and rainbow HSL cycling.

### Data Structures
- **`RingBuffer.swift`** — Fixed-capacity circular buffer. O(1) append/removeFirst.
- **`TrailPoint.swift`** — `position: CGPoint`, `timestamp: CFTimeInterval`, `velocity: CGFloat`.
- **`SpeedMode.swift`** — `.fixed` or `.adaptive` (width scales with mouse velocity).

### Configuration
- **`TrailConfiguration.swift`** — All tunable parameters in one `Sendable` struct: color, thickness, length, fade speed, rainbow speed, diminishing, speed mode, opacity, glow.
- **`TrailColor.swift`** — `.solid(Color)`, `.gradient(Color, Color)`, `.rainbow`.
- **`TrailStyle.swift`** — `.line` (multi-pass stroked) or `.ribbon` (filled spline).
- **`GlowConfig.swift`** — Optional glow: radius, intensity (0-1), optional custom color.

### Demo & Testing
- **`Examples/CursorTrailDemo/main.swift`** — SwiftUI app with live controls for all parameters.
- **`Tests/CursorTrailTests/`** — Self-hosted test harness (custom `XCTAssert*`, not XCTest). Tests `RingBuffer` (empty, append, overwrite, clear) and `TrailConfiguration` (defaults, custom values).
- **`Tests/TestRunner/main.swift`** — Verifies the module loads.

## Important Notes
- Tests use a custom assertion harness, not XCTest. Do not add XCTest-based tests.
- `TrailRenderer` flips Y-coordinates for macOS screen space (`NSScreen.main?.frame.height`).
- Mouse movement detection uses 0.5px squared-distance threshold to avoid jitter.
- Rainbow mode uses HSL hue rotation in `TrailRenderer.colorForTrail()`.
- Particles were removed in v0.2.0 due to instability. Do not reintroduce without thorough testing.