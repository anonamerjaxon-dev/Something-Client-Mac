# Something-Client-Mac

A macOS UI enhancement toolkit inspired by Minecraft hack client aesthetics. This is my first project — learning as I go.

## Modules

### Existing

#### [CursorTrail](cursor%20trail/README.md)

A lightweight Swift library that draws a smooth, animated trail behind the mouse cursor. Renders on a transparent overlay at `.screenSaver` window level — floating above everything while passing clicks through.

```swift
import CursorTrail
CursorTrail().start()
```

Full documentation and API reference → [cursor trail/README.md](cursor%20trail/README.md)

### Planned

The core systems are the **HUD** (heads-up display overlay) and the **Client** (central module manager), which will tie everything together.

| Module | Description |
|---|---|
| **Totem Pop** | A totem animation appears when the Mac detects a sudden motion — like slapping the desk or laptop. Uses the built-in motion sensor. |
| **Customizable Cursor** | Replace the default cursor with custom images. Different images for different states (normal, hover, drag, busy), with full control over the exact click point. |
| **Moving Wallpaper** | Import MP4 videos to set as a live animated desktop background. |
| **Fun Wallpapers** | Conway's Game of Life and other cellular automata play out randomly on the desktop. Customize the rules, colors, speed, and grid size. |
| **Window Drag Trail** | A trail effect follows windows as you drag them around the screen. |
| **Music Display** | A real-time audio visualizer showing frequency levels — like those bouncing bar displays — for whatever audio is playing. |
| **Black Hole** | Still brainstorming... |

---

## Updates

### 2026-07-22 — v0.2.0 Cleanup & Optimization

- **Removed** particle effects system — scrapped due to instability
- **Fixed** thread safety in CVDisplayLink with proper `Unmanaged` retain/release
- **Fixed** use-after-free potential in display link callback
- **Rewrote** demo app UI with clean, sectioned layout
- **Updated** README and documentation

### 2026-07-01 — v0.1.0 Initial Release

- Cursor trail with rainbow, solid, and gradient color modes
- Ribbon and line rendering styles
- Adaptive speed-based width
- Glow effect support
- CVDisplayLink vsync-synced rendering
- Builder pattern API