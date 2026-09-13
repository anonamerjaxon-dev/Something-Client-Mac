# DesktopCanvas — Mid-Point Review & Forward Plan

## Your role

You are an expert macOS/Swift engineer conducting a thorough design review of DesktopCanvas.
You are free to research, question, and improve upon anything. Nothing is sacred.

Your job:
1. Read and understand every file built so far (Phases 0-5)
2. Cross-check against the original design spec
3. Identify architectural gaps, bugs, and anti-patterns
4. Propose improvements — even if it means rewriting
5. Plan the remaining phases with concrete implementation details

This is a **rewind**. You have full authority to suggest changes. The code works but
may have issues. Find them.

---

## Step 0: Read the spike code first

The spike code IS the reference. It's proven on macOS Tahoe 26.6.2. Read it before
touching anything else. These are working implementations:

### S0.1 — Window Level Test (THE reference for all window behavior)
Location: `desktop-canvas/Spike/WindowLevelTest/Sources/main.swift`
- This is the exact window config that works: level, collection behavior, z-order
- Read it fully. It's short and it's the single most important file.

### S0.2 — Compositing Test (MTKView + AVPlayerLayer coexistence)
Location: `desktop-canvas/Spike/CompositingTest/Sources/main.swift`
- Proves MTKView and AVPlayerLayer render side-by-side without flicker
- Shows the correct MTKView setup pattern (delegate, isPaused, enableSetNeedsDisplay)

### S0.3 — Permissions Test
Location: `desktop-canvas/Spike/PermissionsTest/Sources/main.swift`
- Proves no permissions needed for desktop-level windows

### S0.4 — Game of Life Metal Spike (THE reference for all Metal code)
Location: `desktop-canvas/Spike/GameOfLifeSpike/Sources/main.swift`
- Working Metal compute + render pipeline at 500x500 cells, 60fps
- Shows: double-buffer ping-pong, 16x16 threadgroups, toroidal wrapping,
  fragment shader viewport mapping, drawableSize vs bounds

### S0.5 — Loop Test
Location: `desktop-canvas/Spike/LoopTest/Sources/main.swift`
- Working AVPlayer loop: actionAtItemEnd, seek to zero, notification handler
- ~55ms gap, acceptable

### Lessons learned (from REPORT.md)
Location: `desktop-canvas/Spike/REPORT.md`
- 6 mistakes made during Phase 0 that should not be repeated
- Read these carefully

---

## Step 1: Read all production code (Phases 1-5)

Read every file in full:

```
desktop-canvas/Sources/DesktopCanvas/
├── Canvas.swift           ← Canvas model, CanvasType, GameOfLifeConfig, VideoConfig
├── CodableColor.swift     ← RGBA color, Codable
├── CanvasLayout.swift     ← name + [Canvas], load/save JSON
├── RuleSet.swift          ← 9 presets, B3/S23 parser
├── CanvasProvider.swift   ← protocol: attach/detach/update/pause/resume
├── CanvasRenderer.swift   ← NSView wrapper, masksToBounds
├── GameOfLifeProvider.swift ← MTKView subclass, Metal compute, timer
├── VideoProvider.swift    ← AVPlayer + AVPlayerLayer, loop, placeholder
├── CanvasWindow.swift     ← NSWindow at desktop level, factory, layoutCanvases
├── ScreenManager.swift    ← per-screen windows, hot-plug, NSApplication lifecycle
└── DesktopCanvas.swift    ← singleton, apply/stop/refresh, 10M cap, preset paths
```

Read the Package.swift too:
```
desktop-canvas/Package.swift
```

---

## Step 2: Read the design spec

Location: `desktop-canvas/docs/superpowers/specs/2026-09-12-desktop-canvas-design.md`

Read the full spec. Then answer:

1. Does the current code implement every requirement?
2. What's missing?
3. What's implemented differently than specified? (And is the difference justified?)

---

## Step 3: Read the master implementation plan

Location: `desktop-canvas/docs/superpowers/plans/2026-09-12-desktop-canvas.md`

Check phase-by-phase: what's done, what's deferred, what's next.

---

## Step 4: Architectural review — questions you must answer

### Canvas z-ordering and overlap
The current CanvasWindow implements z-ordering (first canvas = bottom, last = top).
But the design spec says: **"No two canvases may share any pixels."** Canvases should
NEVER overlap. If they can't overlap, z-ordering is irrelevant.

- Is the z-ordering code dead weight if we enforce no-overlap?
- Phase 6 (OverlapResolver) was planned as editor-side only. Should the window
  also detect and warn about overlaps at apply() time?
- What happens if a user manually edits a JSON preset and creates overlapping canvases?

### CanvasRenderer lifecycle
`CanvasRenderer` calls `provider.attach(to:frame:)` in its `init` with `self.bounds`
(which is `.zero` at init time). Then `CanvasWindow` sets `renderer.frame = canvas.frame`
which triggers `setFrameSize` → `provider.update()`.

- Does the brief 0x0 frame cause visual glitches (black flash)?
- Should the renderer accept an initial frame, or should attach be deferrable?
- GameOfLifeProvider creates grid of `max(1, floor(0 / cellSize))` = 1x1 initially.
  Is this wasteful? Does it cause a visible 1-cell flash?

### GameOfLifeProvider — MTKView as Provider
`GameOfLifeProvider` IS an MTKView — it subclasses MTKView AND conforms to CanvasProvider.
This means every instance creates a Metal device, pipeline, buffers, and timer in init.

- Is creating all Metal resources in `init()` correct, or should they be created
  lazily in `attach()`? Currently, if you create a provider but never attach it,
  you've allocated Metal resources for nothing.
- The timer starts in `init()` via `scheduleTimer()`. If paused=false (default),
  the timer fires immediately. But there's no superview yet — the MTKView's `draw(in:)`
  checks `guard let drawable = currentDrawable` which fails silently. Is this a
  resource waste? Should the timer only start on attach?
- `reallocateGrid` copies old grid state into new buffer using nested loops on CPU.
  For large grids (1000x1000), this is 1M iterations on a single thread. Should this
  be a Metal blit or at least memcpy when possible?

### VideoProvider — missing file detection
`showPlaceholder` creates an NSView with dark gray background and "⚠ Missing Video"
text. But this runs on the desktop — is a static gray rectangle visible behind icons
acceptable UX? Should there be a way for the editor to surface this error?

### ScreenManager — NSApplication lifecycle
`ScreenManager.apply()` calls `NSApp.run()` which blocks. This function never returns
until `stop()` calls `NSApp.terminate(nil)`. After `stop()`, `NSApp` is terminated
and can't be restarted.

- What happens if you call `apply()`, `stop()`, then `apply()` again? (Hint: NSApp
  is dead after terminate.)
- Should the demo app control NSApplication instead, with ScreenManager just
  managing windows?

### DesktopCanvas — singleton and state
- `DesktopCanvas.shared.apply()` calls `stop()` first, then creates a new ScreenManager.
  If `stop()` terminated NSApp, can we restart it?
- `saveLastUsedPreset` is called on every `apply()`. Is auto-save the right behavior,
  or should saving be explicit?

### Performance
- 10M cell cap: is this enforced anywhere besides a print statement?
- Multiple GameOfLife canvases: each has its own timer, MTKView, command queue.
  Can Metal handle 20 MTKViews simultaneously on one screen?
- VideoProvider: what if the MP4 is 8K? Does it decode fine or degrade?

---

## Step 5: Forward planning (Phases 6-12)

For each remaining phase, think critically about approach:

### Phase 6: Overlap prevention
The spec says "no two canvases may share any pixels." Options:
- A) Push-out resolver: on drag, find nearest non-overlapping position
- B) Grid-snapping: canvases snap to a grid like window managers do
- C) Declarative: editor validates and rejects overlapping placements
- D) Something else you discover?

Which approach is least surprising for users? What about resizing vs dragging?

### Phase 7: Preset persistence
Currently `_last_used.json` is auto-saved. The spec wants `save/load/delete/list`.
Is this just extending DesktopCanvas with CRUD methods on the presets directory?

### Phase 8-9: Demo app
The spec wants a SwiftUI app. But DesktopCanvas is an AppKit library with an
NSApplication.run() loop. Can SwiftUI and AppKit run loops coexist?
- Option A: The demo app IS the NSApplication. ScreenManager doesn't call run().
- Option B: DesktopCanvas runs in its own process, demo app communicates via XPC.
- Option C: Something else?

### Phase 10: Grid editor + BrushTool
Deferred from Phase 1. BrushTool was planned as an enum with pencil/line/rect/fill/random.
- Bresenham line algorithm
- Flood fill (BFS vs DFS — which handles large grids better?)
- Random seed at configurable density

The grid editor is an interactive view where the user draws on the Game of Life grid.
- Should it use the same Metal renderer as the live canvas?
- How to communicate drawn cells to the running GameOfLifeProvider?

### Phase 12: Testing
The spec says "custom harness, NOT XCTest." What does a custom harness look like?
- A Swift script that imports DesktopCanvas and runs assertions?
- A separate executable target?
- Command-line test runner?

---

## Step 6: Deliverable

After completing Steps 0-5, produce a single document saved to:

```
desktop-canvas/docs/superpowers/plans/2026-09-12-review-and-forward-plan.md
```

This document should contain:

1. **Review summary** — what's correct, what's wrong, what's missing
2. **Bugs found** — with file, line, description, and recommended fix
3. **Architectural concerns** — decisions that should be reconsidered
4. **Revised Phase 6-12 plan** — concrete implementation details, not vague descriptions
   - Each phase: which files to create/modify, exact APIs, key algorithms
   - Dependencies between phases (can any run in parallel?)
   - Risk areas and mitigation
5. **Open questions** — things you couldn't determine from code alone, need human decision
6. **Research directions** — areas where you'd want to spike before building

Write the document as if you're briefing a senior engineer who will implement
Phases 6-12. Be specific. Reference line numbers. Propose concrete code when
you're confident; flag uncertainty when you're not.

---

## Constraints

- Read ALL files before forming conclusions. No skimming.
- Cross-reference the spike code with the production code. If production differs,
  determine whether it's an improvement or a regression.
- If you find a bug, say where and how to fix it. Don't just say "this looks wrong."
- For forward planning, prioritize concrete over abstract. "Create file X with
  struct Y that has method Z" beats "we should think about overlap."
- The user said: "canvases shouldn't be able to overlap." This is a requirement,
  not a suggestion. All overlap must be impossible — in the editor, in JSON,
  at runtime.

## Anti-constraints (what you're allowed to do)

- You CAN propose deleting code if it's dead weight
- You CAN propose a different architecture than what's built
- You CAN question design decisions made in earlier phases
- You CAN and SHOULD propose research spikes for uncertain areas before committing
- You ARE allowed to be wrong — flag uncertainty, don't fake confidence