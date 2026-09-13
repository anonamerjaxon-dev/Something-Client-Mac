# DesktopCanvas

Desktop wallpaper and procedural art module — render animated content behind
desktop icons with native performance and zero input interference.

## What it does

Replaces the static macOS desktop wallpaper with dynamic content:
- **Video canvases**: MP4/MOV playback via AVPlayer, aspect-ratio locked
- **Game of Life canvases**: GPU-accelerated cellular automata via Metal compute

Canvases are placed freely on the desktop, persist across Spaces and Mission Control,
and sit **behind** desktop icons so Finder interaction works normally.

## Architecture

```
desktop-canvas/
├── Sources/
│   ├── DesktopCanvas/          ← Library (stable, proven)
│   │   ├── Canvas.swift        — CanvasModel, CanvasType, GameOfLifeConfig, VideoConfig, RuleSet, CodableColor
│   │   ├── CanvasLayout.swift  — Persistable layout (name + [CanvasModel]), save/load to JSON
│   │   ├── CanvasProvider.swift— Protocol for content providers (attach/detach/update/pause/resume)
│   │   ├── CanvasRenderer.swift— NSView wrapper, delegates lifecycle to provider
│   │   ├── CanvasWindow.swift  — Desktop-level NSWindow per screen (kCGDesktopIconWindowLevel)
│   │   ├── ScreenManager.swift — NSScreen listener, per-screen window lifecycle, hot-plug
│   │   ├── DesktopCanvas.swift — Public API: apply(layout:), stop(), refresh(), presets
│   │   ├── GameOfLifeProvider.swift — Metal compute kernel for Conway + 9 rule variants
│   │   ├── VideoProvider.swift — AVPlayer + AVPlayerLayer, seamless loop, occlusion-aware
│   │   ├── OverlapResolver.swift — Runtime overlap validation at apply() time
│   │   └── RuleSet.swift       — Game of Life rule definitions (B3/S23 notation), 9 presets
│   │
│   ├── DesktopCanvasDemo/      ← Demo/editor app (SwiftUI)
│   │   ├── EditorState.swift   — ObservableObject: single source of truth, UUID-based mutations
│   │   ├── EditorView.swift    — Main window: toolbar + canvas list + settings panel
│   │   ├── CanvasListView.swift— Canvas list with add/remove/reorder
│   │   ├── CanvasSettingsView.swift — Settings panel: position/size, type picker, config
│   │   ├── VisualLayoutView.swift — Scaled desktop preview: drag, resize, snap feedback
│   │   ├── SnapEngine.swift    — Snap to screen edges, center, canvas edges, layout grid
│   │   ├── ColorWell.swift     — NSColorWell bridge for SwiftUI
│   │   └── main.swift          — SwiftUI app entry point
│   │
│   └── DesktopCanvasTest/      ← Quick integration test harness
│
├── Spike/                       ← Research spikes (reference, do not modify)
│   └── REPORT.md                — Phase 0 findings: window levels, Metal pipeline, compositing
│
└── docs/superpowers/
    ├── specs/                   — Design specification
    └── plans/                   — Phase implementation plans
```

## Quick start

```bash
# Build the library + demo app
cd desktop-canvas
swift build

# Run the demo editor
swift run DesktopCanvasDemo

# Run the integration test
swift run DesktopCanvasTest
```

## Demo app usage

1. **Add a canvas** — click `+` and choose Game of Life or Video
2. **Position it** — drag in the visual layout view; snaps to screen edges, other canvases, and grid
3. **Configure** — select a canvas to edit settings (cell size, colors, video file, etc.)
4. **Apply to Desktop** — renders behind desktop icons, persists across Spaces
5. **Stop** — removes all canvases from the desktop

### Snap helpers
- Snap to screen edges, center, adjacent canvas edges, or grid (50pt default)
- Hold **⌘** to temporarily disable snapping
- **Fill Screen** button: fills the entire screen (aspect-fill for video, cell-size-snapped for GoL)
- Video canvases are aspect-ratio locked — resizing preserves the video's natural proportions

## Current state (Phase 8 complete)

### ✅ Working
- Desktop-level rendering at `kCGDesktopIconWindowLevel` (behind icons, survives Spaces, Mission Control, Show Desktop)
- Multi-screen support with hot-plug detection
- Game of Life: Metal GPU compute, 9 rule sets, configurable cell size/colors/speed
- Video playback: AVPlayer with seamless looping, aspect-ratio preservation, space-aware pause/resume
- Visual layout editor with drag/resize and snap feedback
- UUID-based state management (no index-out-of-range crashes)
- JSON preset save/load (`_last_used.json` auto-restore)
- Single-window-per-screen architecture (no z-ordering, no overlapping — by design)

### 🚧 Remaining (planned)
- **Grid Editor** (Phase 10): draw cells directly, place patterns (glider, pulsar, etc.), zoom/pan
- **BrushTool integration**: pencil/line/rect/fill drawing tools
- **Pattern library**: pre-built Game of Life patterns
- **Preset Manager UI**: save/load/delete presets from the editor
- **Live overlay mode**: semi-transparent grid overlay on desktop
- **More provider types**: Web/Shadertoy (WKWebView), reaction-diffusion, WireWorld

### ⚠️ Known limitations
- **MP4 codec support**: Some MP4 files use codecs that AVPlayerLayer can decode audio from but won't render video frames (the player state is `.readyToPlay` but `presentationSize` is `.zero`). Converting to MOV usually resolves this. The editor shows a "⚠ Playback failed" placeholder when this occurs.
- **No desktop interaction**: `ignoresMouseEvents = true` always. The architecture allows adding click-through later.
- **macOS 13+**: Requires Ventura or newer (uses modern AVFoundation async APIs).

## Lessons learned (mistakes worth documenting)

### 1. Defer playback until layer is sized
**Problem:** Starting `player.play()` in `attach()` when the AVPlayerLayer frame is `.zero` (before `CanvasRenderer.setFrameSize` fires) causes the decoder to skip video initialization. Only audio plays.
**Fix:** Playback is deferred to `update()` via a `playbackDeferred` flag. The layer is properly sized by then.

### 2. Auto-apply must be async
**Problem:** `autoApplyIfNeeded()` ran synchronously inside SwiftUI binding updates, calling `CanvasWindow.layoutCanvases` which mutates NSView frames. AppKit's dispatch sources get disposed mid-layout → `_dispatch_queue_xref_dispose` crash.
**Fix:** Debounced `DispatchWorkItem` dispatched to the next runloop iteration. Previous work item is cancelled on rapid mutations.

### 3. Structs don't propagate mutations
**Problem:** `VideoProvider` was setting `canvas.videoConfig?.naturalSize` on its local `CanvasModel` copy. `CanvasModel` is a value type — the mutation never reached `EditorState`.
**Fix:** Resolution is read at file-selection time in `EditorState.setVideoURL()`, which owns the source of truth.

### 4. UUID-based state access beats index-based
**Problem:** `CanvasSettingsView` used `state.canvases[index].videoConfig` with indices. When a canvas was added/removed, the index became stale → `Index out of range` crash.
**Fix:** All settings panel mutations go through `mutateCanvas(by: UUID)`, `mutateGoLConfig(by: UUID)`, `mutateVideoConfig(by: UUID)`. These re-resolve the index on each access.

### 5. AVPlayerLayer occlusion is space-aware
**Problem:** Video paused when the demo app window gained focus, then didn't resume when switching back to the desktop Space.
**Fix:** `NSWindow.didChangeOcclusionStateNotification` observer checks `.visible` flag and plays/pauses accordingly.

### 6. AVFoundation async APIs, not semaphores
**Problem:** `DispatchSemaphore.wait()` blocks the main thread while waiting for `loadTracks` completion. Deprecated property access on `AVAssetTrack` (naturalSize, preferredTransform).
**Fix:** `loadTracks` completion handler launches a `Task { @MainActor in ... }` that awaits `track.load(.naturalSize)` and `track.load(.preferredTransform)` — fully async, no deprecation warnings.

## License

Proprietary — Somno Mac Client internal module.