# Phase 8+ Rebuild Plan — September 13, 2026

## Decision: Rewind & Rebuild (Path A)

The previous demo app was built in a single rushed pass (all of Phases 8–11 crammed
into one go). It builds, but it has architectural debt, missing features, and was built
without incremental verification.

This plan tears down the demo app and rebuilds it one phase at a time, verifying
each phase works before moving to the next.

---

## What stays (library is solid)

The library (`Sources/DesktopCanvas/`) is correct and stays as-is with minor cleanup:

- `CanvasModel`, `CanvasLayout`, `CodableColor` — models
- `CanvasProvider` protocol — contract for rendering
- `GameOfLifeProvider` — Metal compute for Game of Life
- `VideoProvider` — AVPlayer video wallpaper
- `CanvasRenderer` — NSView wrapper for providers
- `CanvasWindow` — desktop-level NSWindow per screen
- `ScreenManager` — per-screen window management, hot-plug
- `DesktopCanvas` — public API (`apply`, `stop`, `refresh`, presets)
- `OverlapResolver` — runtime overlap validation at `apply()` time
- `RuleSet`, `BrushTool` — Game of Life utilities

### Library cleanup (minor)

1. **Remove z-ordering from `CanvasWindow.layoutCanvases`** — spec says canvases never
   overlap. The diff-based add/remove with `addSubview` ordering is dead weight.
   Canvases just need to be present; order doesn't matter.

2. **Remove `BrushTool` (for now)** — it's unused by the library and will be
   re-introduced in the demo app's grid editor (Phase 10). Don't ship dead code.

---

## Architecture decisions

### 1. No overlap, ever

The design spec explicitly rules out overlapping canvases. `OverlapResolver.validate()`
at `apply()` time rejects any layout with overlaps. There is no z-ordering, no
layering, no stacking. Canvases are flat tiles on the desktop.

### 2. Snap system (new, Phase 8b)

A unified snap engine for the editor. When moving/resizing a canvas:

| Snap target | Behavior |
|---|---|
| Screen edges | Snap to screen frame boundaries ± margin |
| Screen center | Snap to screen.midX / midY |
| Other canvas edges | Snap to adjacent canvas edges with configurable gap |
| Layout grid | Snap origin/size to a configurable grid (default 50pt) |
| Cell grid (GoL only) | Snap size to cellSize multiples |

Snap is on by default with a ⌘ key override to temporarily disable.
Default grid: 50pt. Default margin (gap between canvases): 0pt.

### 3. Fill actions (Phase 8b)

Quick actions on selected canvas:

| Action | Behavior |
|---|---|
| Fill Screen | Canvas fills the entire screen. Video: aspect-fit letterboxed. GoL: size snapped to cellSize multiples (may leave small bars). |
| Center | Origin = screen center - size/2 |
| Fit Width | Width = screen width, height preserved |
| Fit Height | Height = screen height, width preserved |

### 4. Game of Life sizing model (Phase 8b + Phase 10)

```
cellSize: CGFloat          ← user's one knob (default 8pt, range 2–64pt)
gridWidth  = Int(canvas.width  / cellSize)   ← derived, always integer
gridHeight = Int(canvas.height / cellSize)   ← derived, always integer
```

**Rule:** `canvas.width` and `canvas.height` MUST be multiples of `cellSize`.
No partial cells at edges. The editor's snap engine enforces this.

**Constraints:**

| Constraint | Value | Reason |
|---|---|---|
| Min grid dimension | 10 cells | Below this is not recognizable as Game of Life |
| Max grid dimension | 10,000 cells | 100M cells = ~800 MB; practical ceiling |
| Min cellSize | 2 pt | Sub-pixel on non-Retina below this |
| Max cellSize | 64 pt | Gives ~20 cells on a typical screen |
| Default cellSize | 8 pt | Classic Game of Life look, clear pattern formation |

**Resize behavior:** Preserve existing cells (center-aligned in new grid).
New area filled with dead cells. If new grid is smaller, crop from center outward.

**Visual properties by cellSize on 27" 4K (~163 PPI):**

| cellSize | Physical size | Look |
|---|---|---|
| 2 pt | ~0.3 mm | Static noise — patterns invisible |
| 4 pt | ~0.6 mm | Very fine grain, barely discernible |
| 8 pt | ~1.2 mm | Fine grain, clear patterns |
| 16 pt | ~2.5 mm | Classic look, individual cells visible |
| 32 pt | ~5 mm | Large blocks, toy-like |

### 5. Video: always maintain aspect ratio

Video canvases always letterbox (aspect-fit) within their frame. No stretching,
no cropping for now. The frame defines the maximum area; the video is centered
within it with black bars.

### 6. Pure wallpaper mode (for now)

No desktop interaction. `ignoresMouseEvents = true` always. The architecture
will not preclude adding it later, but we don't build it now.

### 7. Editor state model

`EditorState` is the single `ObservableObject` source of truth:

```swift
class EditorState: ObservableObject {
    @Published var canvases: [CanvasModel]
    @Published var selectedCanvasID: UUID?
    @Published var isApplied: Bool
    @Published var snapEnabled: Bool = true
    @Published var layoutGridSize: CGFloat = 50
    @Published var snapToScreenEdges: Bool = true
    @Published var snapToCanvasEdges: Bool = true
    @Published var margin: CGFloat = 0
}
```

---

## Phase 8a: Demo Foundation

**Goal:** A window with a canvas list, an "Apply to Desktop" button, and basic
add/remove/reorder. Verifies that the library works end-to-end.

### Tasks

1. Delete current `Sources/DesktopCanvasDemo/` entirely
2. Create `DesktopCanvasDemo` executable target (SwiftUI app)
3. Create `EditorState` — ObservableObject with canvas list + apply/stop
4. Create `EditorView` — NSWindow with:
   - Toolbar: Add Canvas (+), Remove (−), Apply, Stop buttons
   - Left: `CanvasListView` — list of canvases with drag reorder, click to select
   - Right: placeholder "Select a canvas to edit" text
5. Create `CanvasListView` — simple list showing canvas type icon + name
6. Wire `EditorState.apply()` → `DesktopCanvas.shared.apply(layout:)`
7. Wire `EditorState.stop()` → `DesktopCanvas.shared.stop()`
8. Auto-load `_last_used.json` on launch

### Verification checklist

- [ ] App launches, shows empty canvas list
- [ ] "+" adds a Game of Life canvas (default: 400×300, cellSize=8, random seed)
- [ ] Canvas appears in list with name "Game of Life"
- [ ] Click "Apply to Desktop" — see Game of Life on wallpaper
- [ ] Switch spaces — canvas follows
- [ ] Click "Stop" — wallpaper reverts
- [ ] Reorder canvases in list — layout re-applies correctly
- [ ] Quit and relaunch — last layout auto-loads

---

## Phase 8b: Snap System + Fill Actions + Visual Layout

**Goal:** Drag/resize canvases on a visual representation of the desktop with
snapping. Quick fill actions for fast layout.

### Tasks

1. Create `SnapEngine` struct — all snap logic in one place
2. Create `VisualLayoutView` — scaled desktop preview:
   - Draws screen rectangle
   - Draws each canvas as a colored rectangle with label
   - Drag to move (with snap)
   - 8 resize handles (with snap, cell-size snap for GoL)
3. Create fill/center actions (toolbar buttons or context menu)
4. Wire snap toggles in toolbar or menu
5. Cell-size snap: when GoL canvas is selected, size snaps to cellSize multiples

### Snap behavior

- Snap threshold: 8 pt (in screen coordinates). If the dragged point is within
  8 pt of a snap line, it snaps.
- Hold ⌘ to temporarily disable snap (macOS convention)
- Snap lines flash briefly when engaged (visual feedback)

### Fill actions

- "Fill Screen" button in toolbar (when canvas selected)
- "Center" button in toolbar
- Context menu: Fill Screen, Fill Width, Fill Height, Center

### Verification checklist

- [ ] Drag canvas in visual layout — snaps to screen edges
- [ ] Drag near screen center — snaps to center
- [ ] Drag near another canvas — snaps to its edge (with margin)
- [ ] Drag near grid line — snaps to grid
- [ ] Resize GoL canvas — size snaps to cellSize multiples
- [ ] Hold ⌘ — snap disabled, free movement
- [ ] Fill Screen on GoL canvas — fills screen, size rounded to cellSize
- [ ] Fill Screen on Video canvas — fills screen, letterboxed aspect ratio
- [ ] Changes in visual layout update the canvas list in real-time

---

## Phase 9: Settings Panel

**Goal:** Edit all properties of a canvas through a settings panel.

### Tasks

1. Create `CanvasSettingsView` — right panel, shown when canvas selected
2. **Type picker:** Segmented control (Game of Life / Video)
3. **Position & Size:** X, Y, Width, Height fields (live update)
4. **Game of Life settings:**
   - Cell size slider (2–64 pt, step 1 pt)
   - Speed slider (1–60 generations/sec)
   - Color wells: alive color, dead color
   - Rule set picker (Conway, HighLife, Seeds, etc.)
   - Density slider (10%–90%, for random seed)
   - Random Seed button, Clear button
   - Play/Pause toggle
5. **Video settings:**
   - File picker (open panel for .mp4/.mov)
   - Volume slider (0–100%)
   - Loop toggle
6. **"Remove Canvas" button** (danger zone, bottom of panel)

### Verification checklist

- [ ] Select Game of Life canvas → see GoL settings
- [ ] Change cell size slider → canvas size snaps to new cellSize multiple
- [ ] Change alive color → wallpaper updates live
- [ ] Select Video canvas → see video settings
- [ ] Pick video file → video plays on wallpaper
- [ ] Switch canvas type (GoL → Video) → canvas resets to default for that type

---

## Phase 10: Grid Editor

**Goal:** Draw on the Game of Life grid. Place patterns. See live changes on desktop.

### Tasks

1. Create `GridEditorView` — opens as a sheet/modal when "Edit Grid" button clicked
2. **Drawing tools toolbar:**
   - Pencil (click/drag to toggle cells)
   - Line (click start, drag, release to draw line)
   - Rectangle (click corner, drag, release to draw filled rect)
   - Eraser (click/drag to kill cells)
3. **Pattern library:**
   - Glider (4 directions)
   - Blinker (horizontal/vertical)
   - Block, Beehive, Boat, Loaf (still lifes)
   - LWSS (4 directions)
   - Pulsar (period 3 oscillator)
   - Gosper Glider Gun
4. **Grid controls:**
   - Zoom in/out (scroll wheel, centered on cursor)
   - Pan (space+drag or two-finger scroll)
   - Show/hide grid lines
   - Random Seed button
   - Clear All button
   - Density slider
5. **Live sync:** Changes to the grid are pushed to the running GameOfLifeProvider
   in real-time via a direct reference (NOT through full refresh).
6. **Cell preview on hover:** Highlight the cell under the cursor

### Grid rendering

- Each cell is a colored square (alive = aliveColor, dead = deadColor)
- Grid lines between cells (subtle, toggleable)
- Zoomed-out view: cells blend together, showing large-scale patterns
- Zoomed-in view: individual cells visible

### Verification checklist

- [ ] Open grid editor — see current state of GoL canvas
- [ ] Click cells — toggle alive/dead
- [ ] Drag with pencil — draw line of live cells
- [ ] Select Glider pattern, click on grid — glider placed
- [ ] Glider moves on desktop wallpaper in real-time
- [ ] Zoom in/out — grid scales correctly
- [ ] Pan — grid scrolls correctly
- [ ] Random Seed — grid fills randomly
- [ ] Clear All — all cells die
- [ ] Close editor — grid state preserved

---

## Phase 11: Preset Manager

**Goal:** Save, load, and delete named presets through the UI.

### Tasks

1. Create `PresetManagerView` — sheet with:
   - List of saved presets (name + date + canvas count)
   - "Save Current" button → name prompt → saves
   - "Load" button → loads selected preset (replaces current layout)
   - "Delete" button → confirmation → deletes
   - "Duplicate" button → copy preset with new name
2. Auto-save on quit (overwrite `_last_used.json`)
3. Warn if unsaved changes exist when loading a different preset
4. Preset file format: JSON in `~/Library/Application Support/DesktopCanvas/presets/`

### Verification checklist

- [ ] Set up a layout with 2 canvases, click Save → name it
- [ ] Preset appears in list
- [ ] Create new layout, load saved preset → reverts
- [ ] Delete preset → disappears from list
- [ ] Quit and relaunch → last layout auto-loads
- [ ] Load preset when changes exist → warns "Discard changes?"

---

## Phase 12: Tests

**Goal:** Unit tests for library components.

### Test targets

1. **OverlapResolverTests** — detect, resolve, validate, edge cases
2. **SnapEngineTests** — all snap targets, threshold, grid alignment
3. **RuleSetTests** — Conway, HighLife, Seeds, custom rules
4. **CanvasModelTests** — encoding/decoding, validation
5. **GameOfLifeProviderTests** — grid allocation, resize, seed, pattern placement

---

## What was deleted (and why)

| File | Reason |
|---|---|
| `Sources/DesktopCanvasDemo/` (all) | Rushed build. Replaced by phased rebuild. |
| `Sources/DesktopCanvas/BrushTool.swift` | Unused in library. Reintroduced in demo Phase 10. |

No other files are modified. The library stays as-is except for the z-ordering
cleanup in `CanvasWindow.layoutCanvases`.

---

## Build command

```bash
cd "desktop-canvas" && swift build
```

Must pass with zero errors, zero warnings after every phase.

---

## Commit plan

Commits happen after each phase is verified:
1. `Phase 8a: Demo foundation — canvas list + apply/stop`
2. `Phase 8b: Snap system + fill actions + visual layout`
3. `Phase 9: Settings panel`
4. `Phase 10: Grid editor with pattern library`
5. `Phase 11: Preset manager`
6. `Phase 12: Tests`