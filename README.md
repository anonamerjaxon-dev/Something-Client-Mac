# Something Client Mac

A macOS UI enhancement toolkit inspired by Minecraft hack-client aesthetics. Built as a learning project — each module adds a distinct visual layer to the macOS experience.

## Modules

### CursorTrail

A Swift library that draws a smooth, animated trail behind the mouse cursor. Renders on a transparent overlay at `.screenSaver` window level — floating above everything while passing clicks through.

```swift
import CursorTrail
CursorTrail()
    .color(.gradient(.cyan, .purple))
    .style(.ribbon)
    .start()
```

→ [cursor trail/README.md](cursor%20trail/README.md) for full API and presets.

### CursorFX *(codenamed Polymorph)*

System-wide custom cursor replacement using WindowServer-level cursor registration. Replaces the stock macOS arrow, ibeam, pointing hand, and more with custom PNG/SVG artwork. Registers images directly into the CoreGraphics cursor registry so custom cursors render natively — no overlay window, no input latency.

This is an **original implementation** built by reverse-engineering the private CGS cursor API surface (the same class of APIs that Mousecape and MaCursor discovered). The approach — registration strategy, enforcement model, state mapping, and image pipeline — is our own.

```swift
import Polymorph
let theme = try CursorTheme.load(directory: skinFolder)
try Polymorph.apply(theme: theme)
```

→ [polymorph/README.md](polymorph/README.md) for skin format, commands, and library API.

> **⚠️ Known issue (Sept 2026):** Custom cursors currently only render during transitional states — app splash/loading screens, Mission Control animations, etc. During normal foreground app usage, macOS reasserts the stock cursor. The registration succeeds but the system has a higher-priority cursor path we haven't intercepted yet. This is the #1 item to solve next session.

### Black Hole (Ghostty)

A GLSL custom shader for the [Ghostty](https://ghostty.org) terminal that renders a physically-accurate Schwarzschild black hole with gravitational lensing, a thin accretion disk, photon ring, and lensed starfield. Integrates null geodesics numerically per pixel.

Three size modes: Pomodoro clock, live Claude Code context-window tracking (via OSC 12 cursor color encoding), and a self-running demo loop.

→ [black hole/ghostty-blackhole-main/README.md](black%20hole/ghostty-blackhole-main/README.md)

### Totem Pop *(in development)*

Reads the Bosch BMI286 IMU accelerometer from Apple Silicon Macs via IOHID to detect sudden motion (desk slap, laptop bump). When triggered, a totem animation will play on screen.

```bash
cd totem\ pop/test
./build.sh
sudo ./build/MotionSensor
```

→ [totem pop/CLAUDE.md](totem%20pop/CLAUDE.md) for hardware requirements and architecture.

## Planned

| Module | Description |
|---|---|
| **HUD** | Heads-up display overlay — the core system all modules plug into |
| **Client** | Central module manager — toggles, config, and coordination |
| **Moving Wallpaper** | MP4 videos as animated desktop background |
| **Fun Wallpapers** | Conway's Game of Life and other cellular automata on the desktop |
| **Window Drag Trail** | Trail effect follows windows as you drag them |
| **Music Display** | Real-time audio visualizer from system audio output |

## Project Structure

```
something client mac/
├── cursor trail/     SwiftPM library — mouse trail rendering
├── polymorph/        SwiftPM library — custom cursor replacement
├── totem pop/        SwiftUI app — motion sensor / totem animation
├── black hole/       Ghostty terminal shader — black hole rendering
├── LICENSE           MIT
└── README.md         ← you are here
```

Each module has its own `Package.swift` (or equivalent), tests, and documentation. They are independent but designed to eventually plug into a shared HUD/Client system.

## Development

```bash
# CursorTrail
cd cursor\ trail && swift build && swift test

# CursorFX / Polymorph
cd polymorph && ./build.sh

# Totem Pop
cd totem\ pop/test && ./build.sh
```

## Architecture Notes

- **CursorTrail** renders via a transparent `NSWindow` at `.screenSaver` level with `ignoresMouseEvents = true`. Rendering is synced to display refresh via `CVDisplayLink`.
- **CursorFX** uses `CGSRegisterCursorWithImages` (private CoreGraphics) to register custom images into WindowServer's cursor cache. The enforcement timer re-registers on a loop to fight the system's tendency to reassert stock cursors.
- **Black Hole** is a single `.glsl` shader file. No custom uniforms — context data is encoded into the cursor color (OSC 12) and decoded by the shader each frame.
- **Totem Pop** uses `IOHIDDeviceOpen` (requires `sudo`) to read raw accelerometer data from the BMI286 chip via `AppleSPUHIDDevice`.

## License

MIT