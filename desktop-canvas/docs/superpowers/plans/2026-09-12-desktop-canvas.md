# DesktopCanvas Implementation Plan

**Date:** 2026-09-12
**Design spec:** `desktop-canvas/docs/superpowers/specs/2026-09-12-desktop-canvas-design.md`

---

## Phase 1: Package scaffold & models

- [ ] 1.1 Create `desktop-canvas/Package.swift`
  - Swift 5.9, macOS 13+, target `DesktopCanvas` (library) + `DesktopCanvasDemo` (executable)
  - Dependencies: none (Metal, AVFoundation, AppKit are system frameworks)
- [ ] 1.2 Create `Sources/DesktopCanvas/` with empty entry file
- [ ] 1.3 Create `Sources/DesktopCanvas/CanvasLayout.swift`
  - `CanvasLayout` struct: `name: String`, `canvases: [Canvas]`, `Codable`
  - `static func load(from url: URL) throws -> CanvasLayout`
  - `func save(to url: URL) throws`
- [ ] 1.4 Create `Sources/DesktopCanvas/Canvas.swift`
  - `Canvas` struct: `id: UUID`, `type: CanvasType`, `frame: CGRect`, configs, `Codable`, `Identifiable`
  - `CanvasType` enum: `.gameOfLife`, `.video`
  - `GameOfLifeConfig` struct: all fields from spec, `Codable`
  - `VideoConfig` struct: all fields from spec, `Codable`
  - `CodableColor` helper (serialize NSColor/Color as RGBA components)
- [ ] 1.5 Create `Sources/DesktopCanvas/RuleSet.swift`
  - `RuleSet` struct: `name`, `birth: Set<Int>`, `survival: Set<Int>`, `Codable`, `Equatable`
  - `static let presets: [RuleSet]` — all 9 presets + custom
  - `init?(bSNotation: String)` — parse `"B3/S23"` string, return nil on invalid
  - `var bSNotation: String` — format back to string
- [ ] 1.6 Create `Sources/DesktopCanvas/BrushTool.swift`
  - `BrushTool` enum: `.pencil`, `.line`, `.rect`, `.fill`, `.random`
  - `func apply(to grid: inout [[Bool]], from start: Point, to end: Point, …)` for each tool
  - Flood fill algorithm (BFS/DFS) for `.fill`
  - Bresenham line algorithm for `.line`
  - Rectangle fill for `.rect`
  - Random seed at density for `.random`

---

## Phase 2: CanvasProvider protocol

- [ ] 2.1 Create `Sources/DesktopCanvas/CanvasProvider.swift`
  - Protocol: `var canvas: Canvas { get set }`, `func attach(to: NSView, frame: NSRect)`,
    `func detach()`, `func update()`
- [ ] 2.2 Create `Sources/DesktopCanvas/CanvasRenderer.swift`
  - `CanvasRenderer: NSView` — content view for a single canvas region
  - Holds a reference to one `CanvasProvider`
  - Routes `draw(_:)` / layout to the provider
  - Clips to bounds (no content bleeding)

---

## Phase 3: Metal Game of Life provider

- [ ] 3.1 Create `Sources/DesktopCanvas/GameOfLifeProvider.swift`
  - Conforms to `CanvasProvider`
  - Creates `MTKView` with Metal device, attaches to content view
  - Holds grid state: `[[Bool]]` double-buffered (current + next)
  - Timer drives generation ticks at `generationsPerSecond` rate
  - `func updateGrid(_ newState: [[Bool]])` — called by editor when user draws
  - Pause/play: toggle the timer
- [ ] 3.2 Create Metal shader file `Sources/DesktopCanvas/Shaders.metal`
  - Compute kernel `gameOfLifeStep`: reads 8 neighbors, applies birth/survival
    rules from a `RuleSetParams` uniform buffer, writes to output
  - Fragment shader `gameOfLifeRender`: reads cell state from buffer, outputs
    `aliveColor` if alive, `deadColor` if dead — both as uniform params
  - Host-side: encode `RuleSetParams` (packed birth/survival as bitmasks),
    `ColorParams` (RGBA float4 alive/dead/margin), grid dimensions
- [ ] 3.3 Margin rendering
  - The canvas frame may be larger than the grid (e.g., 400×300 canvas with
    200×200 grid at cellSize=2)
  - Fragment shader: if pixel is outside grid bounds, output `marginColor`
  - Grid positioned centered in the canvas frame (or top-left configurable)
- [ ] 3.4 Performance: cap grid at 10 million total cells across all canvases
  - Check on `apply()` and on resize; warn in editor if exceeded

---

## Phase 4: Video provider

- [ ] 4.1 Create `Sources/DesktopCanvas/VideoProvider.swift`
  - Conforms to `CanvasProvider`
  - Creates `AVPlayer` + `AVPlayerLayer`, attaches to content view
  - `AVPlayerItemDidPlayToEndTime` → seek to `.zero` → play (seamless loop)
  - Volume default 0.0; set `player.volume` from config
  - Handle missing file: show gray placeholder with "⚠ Missing Video" text
  - On detach: pause player, remove layer

---

## Phase 5: Desktop window & screen management

- [ ] 5.1 Create `Sources/DesktopCanvas/CanvasWindow.swift`
  - `CanvasWindow: NSWindow` subclass
  - Init: `NSWindow(contentRect:screen.frame, styleMask: [.borderless], …)`
  - Properties: `level = CGWindowLevelForKey(.desktopIconWindow) - 1`,
    `ignoresMouseEvents = true`, `hasShadow = false`,
    `backgroundColor = .clear`, `isOpaque = false`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
  - Content view is a plain `NSView`; canvases are added as subviews
  - `func layoutCanvases(_ canvases: [Canvas])` — positions/sizes subviews
    to match each canvas frame, creates/destroys subviews as needed
- [ ] 5.2 Create `Sources/DesktopCanvas/ScreenManager.swift`
  - Owns one `CanvasWindow` per active `NSScreen`
  - Listen to `NSApplication.didChangeScreenParametersNotification`
  - On display added: create new `CanvasWindow` for that screen
  - On display removed: close that screen's window, preserve canvases in model
  - Re-layout all canvases across all windows on any change
- [ ] 5.3 Create `Sources/DesktopCanvas/DesktopCanvas.swift`
  - `static let shared = DesktopCanvas()`
  - `func apply(layout: CanvasLayout)` — creates ScreenManager, applies layout
  - `func stop()` — tears down ScreenManager, stops all providers
  - `func refresh()` — re-layout canvases (e.g., after editor changes a frame)
  - `static func presetsDirectory() -> URL`
  - `static func lastUsedPresetURL() -> URL`
  - `static func saveLastUsedPreset(_ layout: CanvasLayout)`
  - `static func loadLastUsedPreset() -> CanvasLayout?`

---

## Phase 6: Overlap prevention

- [ ] 6.1 Create `Sources/DesktopCanvas/OverlapResolver.swift`
  - `static func resolve(_ moving: Canvas, against others: [Canvas]) -> CGRect`
  - For each other canvas: if `moving.frame.intersects(other.frame)`, push
    `moving.frame` outward (shortest-axis push) until no intersection
  - Call this on every drag/resize tick in the editor
  - Return the resolved (possibly unchanged) frame
- [ ] 6.2 Unit tests: several overlap scenarios (corner collision, edge
  push-past-multiple, no-op when clear)

---

## Phase 7: Preset persistence

- [ ] 7.1 In `DesktopCanvas.swift`:
  - `func savePreset(_ layout: CanvasLayout, name: String)` — writes JSON to
    `~/Library/Application Support/DesktopCanvas/presets/{name}.json`
  - `func loadPreset(named: String) -> CanvasLayout?` — reads JSON
  - `func deletePreset(named: String)` — removes file
  - `func listPresets() -> [String]` — enumerates directory
  - `func applyLastUsedPreset()` — reads last-used URL, loads, calls `apply`
- [ ] 7.2 Ensure `CanvasLayout` Codable round-trips correctly (grid states
  included, colors serialized via `CodableColor`)

---

## Phase 8: Demo app — foundation

- [ ] 8.1 Create `Examples/DesktopCanvasDemo/`
  - `Package.swift` `executableTarget` entry
  - `main.swift`: SwiftUI `@main App` with `WindowGroup`
- [ ] 8.2 Create `Examples/DesktopCanvasDemo/EditorView.swift`
  - Main split view: canvas list (left) | settings (center) | grid editor (right)
  - Owns a `@State CanvasLayout` (the working copy)
  - `[Apply to Desktop]` button at top — calls `DesktopCanvas.shared.apply(layout)`
  - On appear: auto-loads last-used preset via `DesktopCanvas.loadLastUsedPreset()`
- [ ] 8.3 Create `Examples/DesktopCanvasDemo/CanvasListView.swift`
  - `List(canvases) { canvas in … }` with selection binding
  - `[+ Add Canvas]` — appends new `Canvas` with default config (Conway, 200×200,
    centered on primary screen)
  - `[Remove]` on selected canvas with confirmation
  - Drag-to-reorder (using `.onMove`)
  - Each row: type icon, name, dimensions text

---

## Phase 9: Demo app — settings panel

- [ ] 9.1 Create settings form in `EditorView.swift` (or a sub-view)
  - Type picker: `Picker` bound to `canvas.type`
  - Position: `TextField` X/Y/W/H bound to `canvas.frame`, with
    `onSubmit` calling overlap resolver
- [ ] 9.2 Game of Life settings:
  - Rule set: `Picker` of presets; if "Custom" selected, show `TextField`
    for `B3/S23` notation with live validation
  - Cell size: `Stepper` 2–64, step 1
  - Alive/Dead/Margin color: `ColorPicker` bound to `CodableColor` wrappers
  - Speed: `Slider` 1–60, step 1, with `"%.0f gen/s"` label
  - Play/Pause: `Button` toggling `canvas.gameOfLifeConfig?.paused`
  - All changes push to live canvas immediately via `DesktopCanvas.shared.refresh()`
- [ ] 9.3 Video settings:
  - `Button("Choose Video…")` → `NSOpenPanel` filtering `.mp4`
  - Volume: `Slider` 0–100, step 1, with `"%.0f%%"` label
  - Loop toggle: `Toggle`
- [ ] 9.4 Canvas resize:
  - Clicking a canvas in the list selects it; the editor highlights the
    selected canvas frame on the desktop (dashed border overlay or
    temporary highlight)
  - Resize handles at corners/edges in the live overlay mode

---

## Phase 10: Demo app — grid editor

- [ ] 10.1 Create `Examples/DesktopCanvasDemo/GridEditorView.swift`
  - Shown only when selected canvas is `.gameOfLife`
  - `ScrollView` + `MagnificationGesture` for zoomable grid
  - Renders grid as a clickable `Canvas`/`GeometryReader` grid
  - Each cell: `Rectangle` with `.onTapGesture` and `.onDrag` handling
  - Cell color preview: alive = config color, dead = config dead color
- [ ] 10.2 Drawing toolbar
  - `Picker` of tool: Pencil, Line, Rect, Fill, Random
  - `Button("Clear")` — sets all cells to dead
  - `Button("Random Seed")` — fills grid at 50% density
  - Tool cursor changes based on selection (crosshair for pencil, etc.)
- [ ] 10.3 Live overlay
  - Toggle in editor: `"Show Desktop Overlay"`
  - When on: renders a 20% opacity overlay on the desktop canvas showing
    the grid boundaries and current cell states
  - Overlay auto-hides when editor window resigns key
- [ ] 10.4 Real-time sync
  - On any grid edit: debounce 100ms, then call
    `gameOfLifeProvider.updateGrid(newState)` and `DesktopCanvas.shared.refresh()`
  - This means drawing in the editor immediately affects the desktop canvas

---

## Phase 11: Demo app — preset manager

- [ ] 11.1 Create `Examples/DesktopCanvasDemo/PresetManagerView.swift`
  - Sheet/modal with:
    - List of saved preset names
    - `[Save Current as…]` → text field + save button
    - `[Load]` on selected preset → replaces current layout, applies to desktop
    - `[Delete]` on selected preset with confirmation
- [ ] 11.2 Auto-save on apply
  - Every `apply(layout:)` call also saves as the last-used preset
  - On app launch: `DesktopCanvas.shared.applyLastUsedPreset()`

---

## Phase 12: Tests

- [ ] 12.1 Create `Tests/DesktopCanvasTests/main.swift`
  - Custom assertion harness (match CursorTrail pattern — NOT XCTest)
  - `func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String)`
  - `func assert(_ condition: Bool, _ msg: String)`
  - Print summary: "✓ X passed, ✗ Y failed"
  - Exit code 0 on all pass, 1 on any failure
- [ ] 12.2 Test: `CanvasLayout` Codable round-trip
  - Create layout with 2 canvases, encode, decode, compare fields
- [ ] 12.3 Test: `RuleSet` parsing
  - `RuleSet(bSNotation: "B3/S23")` → Conway
  - `RuleSet(bSNotation: "B36/S23")` → HighLife
  - `RuleSet(bSNotation: "invalid")` → nil
  - `RuleSet(bSNotation: "").bSNotation` → outputs correctly
- [ ] 12.4 Test: `BrushTool` algorithms
  - Pencil: toggle a single cell
  - Line: Bresenham line covers expected cells (test horizontal, vertical,
    diagonal)
  - Rect: fill rectangle bounds
  - Fill: flood-fill connected region, stops at alive cell boundaries
  - Random: fills at ~50% density (statistical check, tolerance)
- [ ] 12.5 Test: `OverlapResolver`
  - Two non-overlapping canvases → both unchanged
  - Moving canvas into another → pushed to nearest non-overlapping position
  - Canvas pushed past edge of screen → clamped
- [ ] 12.6 Test: Grid state double-buffer
  - Write to current, verify next is updated, swap, verify counts

---

## Phase 13: Documentation

- [ ] 13.1 `desktop-canvas/README.md`
  - Overview, usage example (SwiftPM dependency + API call)
  - Configuration reference (all CanvasLayout fields)
  - Demo app screenshots / description
  - Known limitations (no Windows exports, macOS 13+)
- [ ] 13.2 `desktop-canvas/CLAUDE.md`
  - Build commands (`swift build`, `swift run`, test harness)
  - Architecture overview (ScreenManager → CanvasWindow → CanvasProvider)
  - Metal pipeline notes (compute kernel dispatch, uniform buffers)
  - Coding conventions (match CursorTrail patterns)
- [ ] 13.3 Update root `README.md`
  - Replace "Moving Wallpaper" + "Fun Wallpapers" rows with "DesktopCanvas"
  - Move DesktopCanvas from "Planned" / "Future ideas" to "Existing modules"
  - Link to `desktop-canvas/README.md`
- [ ] 13.4 Update root `README.md` "Module Map" section if present

---

## Phase 14: Polish & manual verification

- [ ] 14.1 Build: `cd desktop-canvas && swift build` — clean, no warnings
- [ ] 14.2 Run demo: `cd desktop-canvas && swift run DesktopCanvasDemo`
  - Add a Game of Life canvas → verify it renders on desktop behind icons
  - Draw cells in editor → verify live desktop updates
  - Change rule set → verify behavior changes
  - Pause/play/clear → verify each works
  - Add a video canvas → verify looping playback, no audio
  - Enable volume → verify audio plays
  - Drag/resize canvases → verify snap-to-avoid-overlap
  - Save preset, quit, relaunch → verify auto-restore
  - Switch Spaces → verify canvases persist
  - Plug/unplug external display → verify windows create/destroy
  - Click desktop icons → verify normal interaction
- [ ] 14.3 Run tests: `cd desktop-canvas && swift run DesktopCanvasTests` —
  all pass
- [ ] 14.4 Performance: Activity Monitor GPU history — verify <5% GPU usage
  with 3 Game of Life canvases + 1 video at idle

---

## Dependency order

```
Phase 0 (research spikes) ← DO THIS FIRST
    ↓
Phase 1 (models)
    ↓
Phase 2 (protocol)
    ↓
Phase 3 (Game of Life) ←→ Phase 4 (Video)
    ↓                         ↓
    └──────── Phase 5 (window/screen management) ─────┘
                  ↓
            Phase 6 (overlap)
                  ↓
            Phase 7 (presets)
                  ↓
    Phase 8 → 9 → 10 → 11 (demo app)
                  ↓
            Phase 12 (tests)
                  ↓
            Phase 13 (docs)
                  ↓
            Phase 14 (polish)
```

Phases 3 and 4 are independent and can be built in parallel by separate agents.
Phases 8–11 are sequential (each builds on the previous demo view).

---

## Estimated effort

| Phase | Est. lines | Complexity |
|---|---|---|
| 1 — Models | ~250 | Low |
| 2 — Protocol | ~50 | Low |
| 3 — Game of Life Metal | ~400 | High |
| 4 — Video | ~150 | Medium |
| 5 — Window/Screen | ~250 | Medium |
| 6 — Overlap | ~100 | Medium |
| 7 — Presets | ~100 | Low |
| 8 — Demo foundation | ~150 | Medium |
| 9 — Settings panel | ~300 | Medium |
| 10 — Grid editor | ~350 | High |
| 11 — Preset manager | ~100 | Low |
| 12 — Tests | ~300 | Medium |
| 13 — Docs | ~150 | Low |
| 14 — Polish | — | Manual |
| **Total** | **~2,650** | |

---

## Risk Audit & Contingency Plans

Each risk is rated by likelihood (1–5) × impact (1–5) = severity score.
Risks ≥ 12 are flagged as critical and have a Phase 0 research spike.

### R1: Desktop window level rejected or broken on macOS 15+

| Likelihood | Impact | Score |
|---|---|---|
| 3 | 5 | **15 — CRITICAL** |

The entire architecture depends on `CGWindowLevelForKey(.desktopIconWindow) - 1`
(or `kCGDesktopWindowLevel - 1`) placing our content between the system
wallpaper and desktop icons. Apple could change or remove this level at any
time. This is a private/sparse API — it's not in the public headers, though
Electron has used it for years and commercial apps like Dynamic Wallpaper
(updated through 2026) rely on it.

**What could go wrong:**
- macOS 15 Sequoia changed the desktop compositor (widgets now render on the
  desktop itself). The level might be redefined or the wallpaper might render
  on top of our window.
- `CGWindowLevelForKey(.desktopIconWindow)` could return 0 or a wrong value.
- In macOS 14+, `NSView.clipsToBounds` default changed from `true` to `false`,
  which could cause content bleeding.

**Verification (Phase 0 — BEFORE any other code):**
1. Write a spike script that creates a red `NSWindow` at
   `kCGDesktopWindowLevel - 1` / `kCGDesktopIconWindowLevel - 1` and logs
   the actual level integer.
2. Test on macOS 15.x (the development machine). Verify the red window appears
   behind desktop icons but above the wallpaper.
3. Test Mission Control, Spaces switching, full-screen app transitions.
4. Test with Stage Manager enabled.
5. Verify `NSView.clipsToBounds = true` is explicitly set on the content view
   (macOS 14+ changed the default).

**Contingency plan (if broken):**

| Fallback | Description | Trade-off |
|---|---|---|
| **A) `kCGDesktopWindowLevel` directly** | Try the raw integer level (often around -1000). Log and test. | Same risk of breakage, just a different constant. |
| **B) `NSWindow.Level(rawValue: -1000)`** | Hardcode the level integer observed from a working system. | Brittle across OS versions but works as a stopgap. |
| **C) Normal window + `setDesktopImageURL` snapshot** | Render to an offscreen buffer, snapshot, save as PNG, call `NSWorkspace.shared.setDesktopImageURL`. Redo every N seconds for dynamic content. | High latency (seconds between frames). No 60fps. But works for slow Game of Life and static images. Video not possible. |
| **D) ScreenSaver-level overlay (CursorTrail pattern)** | Use `.screenSaver` level window (proven working in CursorTrail module) at full screen. This floats ABOVE icons, not behind them. Hide all desktop icons via Finder defaults. | Icons hidden. Not ideal, but fully functional and proven in this codebase. |
| **E) Abort desktop-level window approach** | Switch to rendering in a regular app window (not on desktop). Ship as a standalone app with its own window, not a wallpaper replacement. | Loses the "wallpaper" experience. But all other features (Game of Life, video, editing) still work perfectly. |

**Recommended strategy:**
1. Phase 0 spike first. If the desktop level works → proceed with plan.
2. If broken: try Fallback B (hardcoded level). If that also fails, use
   Fallback C for static/slow content + Fallback D for video/dynamic content.
3. Last resort: Fallback E (standalone app window mode). Still a great product,
   just not integrated into the desktop.

---

### R2: MTKView compositing with AVPlayerLayer in same NSWindow

| Likelihood | Impact | Score |
|---|---|---|
| 3 | 3 | 9 — Medium |

The plan places multiple `MTKView` subviews (Game of Life) and `AVPlayerLayer`
sublayers (video) inside a single `NSWindow.contentView`. CALayer compositing
between Metal-backed views and CoreAnimation layers can cause:
- Flickering when Metal presents a drawable while AVPlayerLayer updates
- Black flashes at the boundary between views
- Z-order issues where one content type draws over the other

**Mitigation (built into the plan):**
- Each canvas is a separate `NSView` with `clipsToBounds = true` — no overlap
  between canvases means no compositing conflict.
- The window's content view uses `wantsLayer = true` and
  `canDrawSubviewsIntoLayer = true` for proper layer-backed compositing.

**Contingency plan (if broken):**

| Fallback | Description |
|---|---|
| **A) Separate NSWindows per canvas** | Each canvas gets its own desktop-level `NSWindow`. No subview compositing at all. More windows but no rendering conflicts. |
| **B) Single MTKView for all Game of Life** | One MTKView covers all Game of Life canvases on a screen. Each canvas is rendered as a viewport region in the same Metal render pass. Videos get their own windows or use a separate AVPlayerLayer on top. |
| **C) Use CALayer hierarchy for both** | Render Game of Life into a `CALayer` bitmap (via `MTLTexture` → `CGImage` → `CALayer.contents`) instead of live MTKView. Simpler compositing but loses Metal's direct-to-screen performance (extra copy step). |

---

### R3: AVPlayer seamless loop gap

| Likelihood | Impact | Score |
|---|---|---|
| 4 | 2 | 8 — Medium |

`AVPlayerItemDidPlayToEndTime` + `seek(to: .zero)` can produce a visible
frame flash or gap (1–3 frames) because `seek(to:)` is asynchronous.

**Mitigation:**
- Use `player.actionAtItemEnd = .none` and observe the boundary manually
- Pre-roll: seek to `kCMTimeZero`, call `player.play()` immediately,
  and use `AVPlayerItem.seekingWaitsForVideoCompositionRendering` = false
- If gap persists: use two `AVPlayer` instances and crossfade between them
  (one plays while the other pre-buffers the next loop)

**Contingency plan:**

| Fallback | Description |
|---|---|
| **A) `AVPlayerLooper`** | iOS/tvOS only — NOT available on macOS. Can't use. |
| **B) Two-player crossfade** | Create two AVPlayers. Player A plays; when 0.5s remain, Player B seeks to start and begins playing with opacity 0. Crossfade A→B over 0.5s. Swap roles. | 
| **C) `AVAssetReader` + manual frame push** | Read decoded frames via `AVAssetReader`, push to a Metal texture, render on a quad in the existing MTKView. Total control over looping but more code. |

---

### R4: Metal compute kernel correctness for arbitrary rule sets

| Likelihood | Impact | Score |
|---|---|---|
| 2 | 4 | 8 — Medium |

The compute kernel needs to correctly apply arbitrary birth/survival rule
sets from a uniform buffer. The kernel itself is simple (8-neighbor count +
rule lookup), but edge cases:
- Toroidal vs. dead-border boundary conditions: toroidal wraps around
  (standard for Game of Life), dead-border treats outside cells as dead.
  User might expect toroidal.
- Rule packing into a uniform buffer: encode birth set as a 9-bit mask,
  survival set as a 9-bit mask. Kernel does `(neighborCount < 9) && ((mask >>
  neighborCount) & 1)`.
- The kernel dispatches one thread per cell. Threadgroup size should be
  optimized (8×8 or 16×16) for occupancy.

**Mitigation:**
- Unit test the rule encoding/decoding in Swift first (Phase 1.5)
- Use a reference CPU implementation to validate the GPU output for known
  patterns (glider, blinker, block)

**Contingency plan:**

| Fallback | Description |
|---|---|
| **A) CPU fallback for small grids** | If Metal pipeline fails to compile/run, use a Swift CPU implementation for grids under 10,000 cells. Slow at 60fps but works for debugging. |
| **B) Pre-baked rule tables** | Instead of arbitrary rules, ship only the 9 preset rule sets as compile-time constants in the shader. Add custom rules later once the pipeline is stable. |

---

### R5: Mission Control / Exposé shows desktop window

| Likelihood | Impact | Score |
|---|---|---|
| 4 | 2 | 8 — Medium |

When the user invokes Mission Control or Exposé, the desktop canvas window
could appear as a separate tile, looking broken/confusing.

**Mitigation:**
- Add `.stationary` to `collectionBehavior` — prevents the window from
  moving when the user switches Spaces
- Add `.transient` (used by CursorTrail) — may hide from Exposé
- Set `window.skipTaskbar = true` equivalent (macOS: use
  `NSWindowCollectionBehavior.transient` + `.ignoresCycle`)
- Explicit `NSWindowCollectionBehavior`:
  ```swift
  window.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,       // stays put during Exposé
      .transient,        // may hide from Mission Control
      .ignoresCycle      // excluded from Cmd+Tab
  ]
  ```

**Contingency plan:**

| Fallback | Description |
|---|---|
| **A) Set `window.level = kCGDesktopWindowLevel - 1`** | At this level, the window is part of the desktop "background" and macOS might not expose it to Mission Control at all. |
| **B) Hide window during Mission Control** | Observe `NSWorkspace.activeSpaceDidChangeNotification` or use a `CGEventTap` to detect Exposé activation. Hide the window during the transition. Adds complexity. |
| **C) Accept it** | If the window shows as a small tile in Mission Control, it may not matter much — many users never use Mission Control on the desktop space. |

---

### R6: Screen recording permission required

| Likelihood | Impact | Score |
|---|---|---|
| 2 | 3 | 6 — Medium |

CursorTrail uses `CGDisplayHideCursor` which requires Accessibility
permission, and its overlay at `.screenSaver` level may require Screen
Recording permission on macOS 14+.

Our desktop-level window is at a lower level than icons and does NOT hide
the cursor or capture any pixels. It should NOT require either permission.

**Verification (Phase 0 spike):**
- Create a minimal desktop-level window and verify it renders without
  triggering the Screen Recording permission dialog.
- If permissions ARE required, add a permissions check like CursorTrail's
  `PermissionsManager` and guide the user through System Settings.

**Contingency:** If Screen Recording permission is required, add the same
permission flow CursorTrail uses. It's a one-time setup per app. Not ideal
but acceptable.

---

### R7: Performance — many MTKViews competing for GPU time

| Likelihood | Impact | Score |
|---|---|---|
| 3 | 3 | 9 — Medium |

Each `MTKView` creates its own `CAMetalLayer`, command buffer, and render
pass. With 10+ Game of Life canvases, that's 10+ MTKViews each submitting
work to the GPU. This introduces overhead from multiple command buffer
submissions.

**Mitigation:**
- Share a single `MTLDevice` and `MTLCommandQueue` across all MTKViews
- Set `mtkView.isPaused = true` on canvases where the game is paused
- Use `mtkView.preferredFramesPerSecond = 30` for slower generations
- Cap total cells at 10 million (soft cap in editor)

**Contingency plan:**

| Fallback | Description |
|---|---|
| **A) Single MTKView, multiple render passes** | One MTKView per screen. Each frame, iterate all Game of Life canvases: set viewport scissor, dispatch compute, render to that region. Single command buffer submission. Best performance. |
| **B) Manual display link + single command buffer** | Don't use MTKView's built-in render loop. Use a single `CVDisplayLink` (like CursorTrail), manually create `CAMetalLayer`s, and submit one command buffer per frame handling all canvases. Maximum control, more code. |

This is the approach I'd recommend going with from the start (Fallback A),
rather than waiting for it to become a problem. The per-canvas MTKView
approach in the main plan is simpler to implement first but should be
refactored to the single-MTKView approach if any performance issue appears.

**Updated architecture recommendation:**
```
ScreenManager
  └── CanvasWindow (one per NSScreen)
       ├── contentView (NSView, wantsLayer=true)
       │   ├── MetalRendererView (single MTKView, fills entire screen)
       │   │     → renders ALL Game of Life canvases as viewport regions
       │   ├── Video0View (NSView + AVPlayerLayer, positioned at canvas frame)
       │   ├── Video1View (NSView + AVPlayerLayer, positioned at canvas frame)
       │   └── ...
       └──
```
This eliminates R2 entirely and mitigates R7. The plan phases should be
updated to reflect this.

---

### R8: macOS 14+ `NSView.clipsToBounds` default change

| Likelihood | Impact | Score |
|---|---|---|
| 5 | 2 | **10 — High** |

In macOS 14 Sonoma, Apple changed `NSView.clipsToBounds` default from `true`
to `false`. This means subviews and sublayers can draw outside their bounds
unless explicitly clipped. For DesktopCanvas, this means:
- Game of Life cells could render outside their canvas frame
- Video could bleed into adjacent canvases
- The overlap prevention system would be visually undermined

**Mitigation:**
- Explicitly set `clipsToBounds = true` on every canvas subview and the
  window content view. Do NOT rely on defaults.
- Add `CALayer.masksToBounds = true` on any `CALayer` instances.

This is a simple fix — just be explicit. But easy to miss. Added as a
reminder in Phases 5 and 7.

---

### R9: Preset file format compatibility across versions

| Likelihood | Impact | Score |
|---|---|---|
| 2 | 4 | 8 — Medium |

`CanvasLayout` is `Codable`. If we add fields in future versions, old preset
files won't decode. This will break the auto-restore feature on update.

**Mitigation:**
- Use optional properties with defaults for all `GameOfLifeConfig`/`VideoConfig`
  fields
- Add a `version: Int` field to `CanvasLayout` (default 1)
- On decode failure, log a warning and reset to default layout (don't crash)

**Contingency:** If format changes dramatically between versions, include a
migration function that reads v1 format and outputs v2 format.

---

### Research spike (Phase 0) — must complete before Phase 1

Before writing any production code, execute these verification steps:

- [ ] **S0.1** Desktop window level verification
  - Create `desktop-canvas/Spike/WindowLevelTest/` with a minimal Swift script
  - Create `NSWindow` at `kCGDesktopWindowLevel - 1` and
    `kCGDesktopIconWindowLevel - 1`, fill with red, log actual levels
  - Verify it renders behind icons, above wallpaper
  - Test on macOS 15.x (the development machine)
  - Test Spaces switching, Stage Manager, full-screen apps

- [ ] **S0.2** MTKView + AVPlayerLayer compositing test
  - Create a spike with one MTKView (colored quads) and one AVPlayerLayer
    (looping video) in the same NSWindow.contentView
  - Verify no flickering, no black flashes, correct z-order

- [ ] **S0.3** Permission check
  - Verify the desktop-level window does NOT trigger Screen Recording or
    Accessibility permission prompts
  - If it does, document which permission and plan how to guide users

- [ ] **S0.4** Metal compute kernel spike
  - Write a minimal Game of Life compute kernel (one grid, Conway rules)
  - Verify dispatch, buffer swap, and fragment shader rendering work
  - Profile: 500×500 grid at 60fps

- [ ] **S0.5** AVPlayer seamless loop spike
  - Create AVPlayer with a test MP4, loop 10 times
  - Measure frame gap at loop boundary
  - If gap exists, prototype the two-player crossfade approach

If any spike fails with no viable contingency, the plan must be revised
before proceeding to Phase 1.