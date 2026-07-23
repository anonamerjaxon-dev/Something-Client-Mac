# Something-Client-Mac

A macOS UI enhancement toolkit inspired by Minecraft hack client aesthetics. This is my first project — learning as I go.

## Modules

### [CursorTrail](cursor%20trail/README.md)

A lightweight Swift library that draws a smooth, animated trail behind the mouse cursor. Renders on a transparent overlay at `.screenSaver` window level — floating above everything while passing clicks through.

```swift
import CursorTrail
CursorTrail().start()
```

Full documentation and API reference → [cursor trail/README.md](cursor%20trail/README.md)

---

## Updates

### 2025-07-22 — v0.2.0 Cleanup & Optimization

- **Removed** particle effects system — scrapped due to instability
- **Fixed** thread safety in CVDisplayLink with proper `Unmanaged` retain/release
- **Fixed** use-after-free potential in display link callback
- **Rewrote** demo app UI with clean, sectioned layout
- **Updated** README and documentation

### 2025-07-21 — v0.1.0 Initial Release

- Cursor trail with rainbow, solid, and gradient color modes
- Ribbon and line rendering styles
- Adaptive speed-based width
- Glow effect support
- CVDisplayLink vsync-synced rendering
- Builder pattern API