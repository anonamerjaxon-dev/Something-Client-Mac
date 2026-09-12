# DesktopCanvas — Desktop Wallpaper & Procedural Art Module

**Date:** 2026-09-12
**Status:** Approved design, pending implementation
**Module:** `desktop-canvas/` (Somno Mac Client)

## Problem

Replace the static macOS desktop wallpaper with dynamic content — videos (MP4)
and procedural artwork (Game of Life, cellular automata) — rendered behind
desktop icons at native performance with zero input interference. Users need:

- Independent content regions (canvases) placed freely on the desktop
- A dedicated editor window for drawing cells, tweaking settings, and managing
  canvases — never interacting directly with the desktop surface
- Multiple rule sets for Game of Life beyond classic Conway
- Save/load of entire canvas layouts as presets

## Chosen technique

A desktop-level `NSWindow` at `CGWindowLevelForKey(.desktopIconWindow) - 1`
— the same approach used by Electron's `desktop` window type and every macOS
video wallpaper project. This places our content between the system wallpaper
and desktop icons, so:

- Icons and Finder interaction work normally (they're on a higher level)
- Content renders at native resolution with no input blocking
  (`ignoresMouseEvents = true`)
- `canJoinAllSpaces` + `fullScreenAuxiliary` collection behavior ensures the
  canvas appears on every Space
- One window per screen (via `NSScreen.screens`), refreshed on display
  hot-plug via `NSApplication.didChangeScreenParametersNotification`

Rendering: **Metal** (`MTKView`) for procedural content (GPU compute kernels
for cellular automata) and **AVPlayer** for video. Both are hardware-accelerated
with negligible CPU cost.

## Non-goals for v0.1

- Web/Shadertoy provider (WKWebView — designed for, added later)
- Procedural types beyond Game of Life (reaction-diffusion, WireWorld, etc.
  are future additions)
- Video playlist per canvas (single MP4 only)
- Canvas z-ordering / overlapping (canvases snap to avoid overlap)
- Windows `.dream` / dynamic HEIF import
- Theme marketplace/gallery UI

## Architecture

SwiftPM package, mirroring the CursorTrail module layout:

```
desktop-canvas/
├── Package.swift
├── Sources/
│   └── DesktopCanvas/
│       ├── DesktopCanvas.swift            — entry: apply(layout:), stop()
│       ├── CanvasWindow.swift             — desktop-level NSWindow per screen
│       ├── ScreenManager.swift            — NSScreen listener, per-screen window lifecycle
│       ├── CanvasLayout.swift             — model: array of Canvas + save/load presets
│       ├── Canvas.swift                   — single canvas: type, rect, config
│       ├── CanvasProvider.swift           — protocol all content types conform to
│       ├── GameOfLifeProvider.swift       — Metal compute kernel for Conway + variants
│       ├── VideoProvider.swift            — AVPlayer + AVPlayerLayer loop
│       ├── CanvasRenderer.swift           — MTKView subclass, routes draw calls to providers
│       ├── RuleSet.swift                  — Game of Life rule definitions (B3/S23 notation)
│       └── BrushTool.swift                — pencil/line/rect/fill drawing logic
├── Examples/
│   └── DesktopCanvasDemo/
│       ├── main.swift                     — SwiftUI app entry
│       ├── EditorView.swift              — canvas list, settings panel
│       ├── GridEditorView.swift          — grid preview + drawing tools
│       ├── CanvasListView.swift          — add/remove/reorder canvases
│       └── PresetManagerView.swift       — save/load layout presets
└── Tests/
    └── DesktopCanvasTests/
        └── main.swift                     — custom assertion harness (NOT XCTest)
```

## Canvas model

```swift
struct CanvasLayout: Codable {
    var name: String
    var canvases: [Canvas]
}

struct Canvas: Codable, Identifiable {
    var id: UUID
    var type: CanvasType           // .gameOfLife or .video
    var frame: CGRect              // position + size on desktop (points)
    var gameOfLifeConfig: GameOfLifeConfig?
    var videoConfig: VideoConfig?
}

enum CanvasType: String, Codable {
    case gameOfLife
    case video
}

struct GameOfLifeConfig: Codable {
    var ruleSet: RuleSet           // preset or custom
    var cellSize: Int              // points per cell (determines grid density)
    var aliveColor: CodableColor
    var deadColor: CodableColor
    var marginColor: CodableColor  // fills the canvas area outside the grid
    var generationsPerSecond: Double
    var gridState: [[Bool]]?       // nil = random seed; stored after editing
    var paused: Bool
}

struct VideoConfig: Codable {
    var videoURL: URL
    var volume: Double             // 0.0–1.0, default 0.0
    var loop: Bool
}

struct RuleSet: Codable, Equatable {
    var name: String               // "Conway", "HighLife", "Custom"
    var birth: Set<Int>            // e.g. [3]
    var survival: Set<Int>         // e.g. [2, 3]
}
```

## Rule sets (v0.1 presets)

| Name | Notation | Birth | Survival | Behavior |
|---|---|---|---|---|
| Conway (default) | B3/S23 | 3 | 2, 3 | Classic life |
| HighLife | B36/S23 | 3, 6 | 2, 3 | Replicator patterns |
| Day & Night | B3678/S34678 | 3, 6, 7, 8 | 3, 4, 6, 7, 8 | Symmetric under inversion |
| Seeds | B2/S | 2 | — | Explosive chaos |
| Maze | B3/S12345 | 3 | 1, 2, 3, 4, 5 | Maze-like structures |
| Anneal | B4678/S35678 | 4, 6, 7, 8 | 3, 5, 6, 7, 8 | Slow, blob-like |
| 2x2 | B36/S125 | 3, 6 | 1, 2, 5 | Blocky oscillators |
| Morley | B368/S245 | 3, 6, 8 | 2, 4, 5 | Stable high-period |
| Diamoeba | B35678/S5678 | 3, 5, 6, 7, 8 | 5, 6, 7, 8 | Amoeba-like shapes |
| Custom | user input | user | user | Freeform |

The custom option exposes a text field accepting standard `B{N}/S{N}` notation,
validated on input.

## Canvas rules

- Canvases may not overlap. When dragging/resizing in the editor, canvases
  snap to avoid collision (push apart or refuse placement).
- One content type per canvas. Layering is achieved by placing separate
  canvases adjacent to each other.
- Minimum canvas size: 32×32 points. Minimum cell size: 2 points. Grid
  dimensions derived automatically: `cols = floor(canvasWidth / cellSize)`,
  `rows = floor(canvasHeight / cellSize)`.

## Editor window (Demo App)

A separate SwiftUI window opened from the demo app. Never interacts with the
desktop surface directly.

### Canvas List (left panel)
- List of all canvases by name, with type icon and dimensions
- `[+ Add Canvas]` button — prompts for type (Game of Life / Video), creates
  at default size centered on the primary screen
- `[Remove]` button on selected canvas
- Drag to reorder (if z-ordering is ever added; currently informational)

### Settings Panel (center)
- Type dropdown (Game of Life / Video)
- Position: X, Y, Width, Height numeric fields
- **Game of Life settings:**
  - Rule set dropdown + custom `B3/S23` text field (shown when "Custom"
    selected)
  - Cell size (points per cell, 2–64)
  - Alive color picker
  - Dead color picker
  - Margin color picker
  - Speed slider: 1–60 generations/second
  - `[▶ Play]` / `[⏸ Pause]` button
- **Video settings:**
  - File picker for MP4
  - Volume slider (0–100%, default 0%)
  - Loop toggle
- `[Apply Changes]` — pushes settings to the live canvas immediately

### Grid Editor (bottom/right panel)
- Scrollable, zoomable grid preview showing current cell state
- Drawing toolbar: `[✏ Pencil]` `[📏 Line]` `[▬ Rect]` `[🪣 Fill]` `[🎲 Random]`
- Click/drag in the grid to toggle cells using the selected tool
- `[Clear]` button — kills all cells
- Changes are pushed to the live canvas in real-time (or on a short debounce)

### Live Overlay Mode
- A toggle in the editor shows a semi-transparent overlay on the desktop
  canvas at 20% opacity so the user can see where cells will render relative
  to their desktop content
- Overlay disappears when the toggle is off or the editor window loses focus

### Preset Manager
- `[Save Preset]` — saves the current full layout (all canvases + config)
  to `~/Library/Application Support/DesktopCanvas/presets/{name}.json`
- Preset list with `[Load]` and `[Delete]` buttons
- On app launch: auto-loads the last-used preset (stored in UserDefaults)

## Apply / stop flow

1. `DesktopCanvas.apply(layout:)`: for each `NSScreen`, create a
   `CanvasWindow` filling the screen. Windows use
   `CGWindowLevelForKey(.desktopIconWindow) - 1`, `ignoresMouseEvents = true`,
   `canJoinAllSpaces = true`, `fullScreenAuxiliary`.
2. Each canvas's `CanvasProvider` attaches its renderer (`MTKView` or
   `AVPlayerLayer`) to the window's content view at the canvas frame.
3. `DesktopCanvas.stop()`: stop all providers, close all windows.
4. `ScreenManager` listens for display changes and recreates windows
   as screens connect/disconnect, restoring all canvases.

## Metal rendering pipeline

```
┌─────────────────────────────────────────────────┐
│  CanvasWindow (NSView content view)              │
│  ┌──────────────────────┐  ┌──────────────────┐ │
│  │ GameOfLifeProvider   │  │ VideoProvider    │ │
│  │ → MTKView            │  │ → AVPlayerLayer  │ │
│  │ → Metal compute      │  │ → hardware       │ │
│  │   kernel (1 thread   │  │   decode         │ │
│  │   per cell)          │  │                  │ │
│  │ → fragment shader    │  │                  │ │
│  │   (colored quads)    │  │                  │ │
│  └──────────────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Game of Life compute kernel
- Dispatch: `MTLSize(width: cols, height: rows, depth: 1)` — one thread per
  cell
- Each thread reads its 8 neighbors, applies the rule set, writes result to
  output buffer
- Double-buffered: input → compute → output, ping-pong each generation
- Fragment shader renders colored quads: alive cells one color, dead cells
  another, margin area a third color
- Generations advance on a timer matching `generationsPerSecond`; paused
  canvases skip the timer tick

### Video rendering
- `AVPlayer` + `AVPlayerLayer` attached as a sublayer of the window's
  content view
- `AVPlayerItemDidPlayToEndTime` notification triggers seek-to-zero for
  seamless looping
- Volume 0.0 by default; `AVPlayer.volume` set when user opts in

### Performance targets
- 60fps with up to 20 Game of Life canvases at 300×300 cells each
  (~1.8 million total cells; compute pass <0.2ms on Apple Silicon)
- Multiple 4K videos at 60fps via hardware decode (essentially free)
- Total GPU frame budget <8ms to leave headroom for the window server
- If total cell count exceeds 10 million, warn in editor (soft cap)

## Editor drawing tools

| Tool | Behavior |
|---|---|
| **Pencil** | Click a cell to toggle it. Click-drag to draw a freehand line of alive cells. |
| **Line** | Click start, drag to end. All cells on the Bresenham line are set alive. |
| **Rect** | Click corner, drag to opposite corner. All cells in the rectangle are set alive. |
| **Fill** | Click a dead cell to flood-fill connected dead region with alive cells. Click an alive cell to kill its connected region. |
| **Random** | Fills the entire grid with a random seed at configurable density (default 50%). |

All tools operate through the grid preview in the editor. Changes are pushed
to the live desktop canvas in real-time (debounced at 100ms to avoid flicker
on rapid edits).

## Canvas overlap prevention

When a canvas is dragged or resized in the editor, the new frame is checked
against all other canvases. If an overlap is detected:
1. The dragged canvas snaps to the nearest non-overlapping position
   (pushed in the direction of the drag until clear)
2. A red flash border indicates the collision was prevented
3. Manual numeric entry in the position fields bypasses snap (user intent)

No two canvases may share any pixels. This simplifies rendering (no compositing
order to manage) and avoids confusing visual overlap with the desktop below.

## Preset persistence

- Saved to `~/Library/Application Support/DesktopCanvas/presets/` as JSON
- Format: `CanvasLayout` encoded via `Codable`
- Grid states included in full (2D boolean array)
- Last-used preset path stored in `UserDefaults` key `lastAppliedPreset`
- On `apply(layout:)`, the layout is auto-saved as the last-used preset
- `DesktopCanvas.loadLastPreset()` is called at demo app launch

## Error handling

- Missing video files: canvas shows a placeholder (gray with error icon) until
  re-linked
- Unreadable rule strings: validation on input; invalid strings revert to
  last valid value
- Display removal: canvases on that screen are preserved in the layout model;
  reappear when the screen reconnects or the user repositions them
- Metal device loss: provider reinitializes the MTKView and restores grid state

## Testing

- Unit tests (custom harness, NOT XCTest): `CanvasLayout` Codable round-trip,
  `RuleSet` parsing/validation, `BrushTool` line/rect/fill algorithms,
  overlap detection math, grid state double-buffering
- Manual verification via demo app: apply → verify canvases render on all
  screens, check icons clickable, Spaces change preserves canvas, editor
  drawing tools flow, pause/play/clear, preset save/load round-trip, video
  loop seamless, display hot-plug restores canvases

## Documentation deliverables

- `desktop-canvas/README.md` — usage, library API, configuration reference
- `desktop-canvas/CLAUDE.md` — commands, architecture, Metal pipeline notes
- Root `README.md` — move DesktopCanvas from Planned to Existing, replace
  "Moving Wallpaper" + "Fun Wallpapers" rows with DesktopCanvas

## References

- Electron `BrowserWindow` desktop type: sets window at
  `kCGDesktopIconWindowLevel - 1` behind icons
- [zhulinghao/wallpaper-mac](https://github.com/zhulinghao/wallpaper-mac) —
  Electron-based macOS video wallpaper using the same level technique
- LiveWallpaperMacOS — native ObjC++ video wallpaper confirming the approach
  works on macOS 15+
- [sindresorhus/macos-wallpaper](https://github.com/sindresorhus/macos-wallpaper) —
  SwiftPM `setDesktopImageURL` API for static image canvases
- CursorTrail module — prior art for transparent overlay windows,
  `canJoinAllSpaces`, CVDisplayLink pattern adapted for Metal