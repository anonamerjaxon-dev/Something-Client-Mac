# DesktopCanvas — Mid-Point Review & Forward Plan

**Date:** 2026-09-13
**Reviewer:** Senior macOS/Swift engineer
**Scope:** Full codebase audit — Spike (S0.1–S0.5), Production (Phases 1–5), Design Spec, Implementation Plan

---

## 1. Review Summary

### 1.1 What's correct and well-executed

| Area | Assessment |
|---|---|
| **Window level** | Exact match with S0.1 spike — raw `CGWindowLevelForKey(.desktopIconWindow)` (-2147483603), not -1. Collection behavior includes `.stationary`, `.transient`, `.ignoresCycle` from spike. `order(.below, relativeTo: 0)` used correctly. |
| **Metal pipeline** | Compute kernel ported from S0.4 spike with improvements: bitmask rule encoding (replaces hardcoded B3/S23), configurable colors via uniform params, `drawableSize`-based scaling (correctly handling Retina). Timer-driven compute (instead of unconditional `needsCompute = true` every frame). |
| **Double-buffering** | Ping-pong `useBufferA`/`bufferA`/`bufferB` correctly swapped after compute dispatch. Both buffers seeded identically on init. |
| **AVPlayer loop** | Matches S0.5 pattern: `actionAtItemEnd = .none` + seek-to-zero + play. Observer removed on detach (no leak). |
| **RuleSet** | 9 presets, bitmask packing, `B{S}/S{B}` parser and formatter. Correct and well-tested. |
| **Canvas model** | Codable, `Identifiable`, 32×32 minimum enforced in `init()`. CGRect encoded as `[Double]` array. |
| **CanvasWindow diff-based layout** | Good pattern: compute added/removed IDs, tear down old, create new, update all. Avoids full teardown on refresh. |
| **ScreenManager hot-plug** | `didChangeScreenParametersNotification` correctly handles screen connect/disconnect. |
| **REPORT.md cross-reference** | Production code incorporated every spike lesson: non-zero MTKView init frame, no `contentScaleFactor` deprecation, `drawableSize` for Metal uniforms, single persistent window pattern, no inline `.metal` file confusion (uses inline string, fine for now). |

### 1.2 What's missing (vs. design spec)

| Spec requirement | Status |
|---|---|
| Canvas overlap prevention at runtime | **MISSING** — no check in `CanvasWindow.layoutCanvases` or `DesktopCanvas.apply()`. Spec says "No two canvases may share any pixels" — must be impossible at runtime, not just editor-side. |
| BrushTool (grid drawing) | **DEFERRED** to Phase 10 (as planned) |
| Grid editor | **DEFERRED** to Phase 10 (as planned) |
| Demo app | **NOT STARTED** |
| Test harness | **NOT STARTED** |
| `clipsToBounds = true` on canvas subviews | **INTENTIONALLY OMITTED** — see Bug #5 below |

### 1.3 Deviations from spec (justified vs. questionable)

| Deviation | Justified? |
|---|---|
| Window level: raw value, not -1 | ✅ **Yes** — S0.1 spike proved -1 breaks Mission Control |
| Collection behavior: added `.stationary/.transient/.ignoresCycle` | ✅ **Yes** — spike-proven; stationary prevents z-order fights |
| Activation policy: `.accessory` not `.prohibited` | ✅ **Yes** — need notifications for hot-plug |
| Factory pattern in CanvasWindow, not caller | ✅ **Yes** — cleaner encapsulation |
| ScreenManager owns NSApp.run() | ⚠️ **Questionable** — see Architectural Concern #3 |
| Auto-save on every apply() | ⚠️ **Questionable** — see Architectural Concern #5 |
| No `clipsToBounds = true` on CanvasRenderer | ❌ **Likely a bug** — see Bug #5 |

---

## 2. Bugs Found

### Bug #1: Canvas JSON decode bypasses 32×32 minimum size

- **File:** `Sources/DesktopCanvas/Canvas.swift`, line ~98-109
- **Description:** `Canvas.init` enforces min size via `max(frame.size.width, 32)` and `max(frame.size.height, 32)`. But the `Codable` initializer `init(from decoder:)` creates the CGRect directly from decoded values without applying the minimum. A hand-edited JSON preset with `"frame": [0, 0, 1, 1]` produces a 1×1 canvas.
- **Impact:** 1×1 canvas → MTKView at 1×1 → `floor(1/4) = 0` → `gridWidth = max(1, 0) = 1` → 1-cell grid → works but violates the contract. Worse: 0×0 canvas → `gridWidth = max(1, 0) = 1`, but `canvas.frame.size` is zero, so `self.frame = canvas.frame` in `update()` produces a zero-size MTKView, which the spike report says causes CVDisplayLink failures.
- **Recommended fix:** Call the designated `init` from `init(from decoder:)` or duplicate the `max(..., 32)` logic:

```swift
// In init(from decoder:), after decoding the [Double] array:
frame = CGRect(
    origin: CGPoint(x: rectValues[0], y: rectValues[1]),
    size: CGSize(
        width: max(rectValues[2], 32),
        height: max(rectValues[3], 32)
    )
)
```

---

### Bug #2: ScreenManager.stop() kills NSApp permanently — restart impossible

- **File:** `Sources/DesktopCanvas/ScreenManager.swift`, line ~44-52
- **Description:** `stop()` calls `NSApplication.shared.terminate(nil)`. Once `NSApp` is terminated, the run loop is dead. A subsequent `apply()` calls `stop()` first (in `DesktopCanvas.swift` line ~18), then creates a new `ScreenManager`, which calls `NSApp.run()` — but `NSApp` is in a terminated state and cannot be re-run.
- **Impact:** Calling `apply()` → `stop()` → `apply()` crashes or hangs. This makes toggling desktop canvases on/off impossible after the first stop.
- **Reproduction:**
  1. `DesktopCanvas.shared.apply(someLayout)` — works
  2. `DesktopCanvas.shared.stop()` — works
  3. `DesktopCanvas.shared.apply(someLayout)` — 💥 NSApp dead
- **Recommended fix:** ScreenManager should NOT own NSApplication lifecycle. Instead:
  - **Option A (preferred):** Demo app owns NSApp. ScreenManager only manages windows. `apply()` just creates windows; `stop()` just closes them. NSApp.run() is called once by the demo app's `@main`.
  - **Option B:** Replace `terminate(nil)` with `NSApp.stop(nil)`, then call `NSApp.run()` again. This is hacky and may not work reliably.
  - **Option C:** Instead of terminate, just hide/close windows and pause the run loop without killing NSApp.

**Note:** This is the single most impactful bug. The current architecture makes `apply()` effectively single-use.

---

### Bug #3: GameOfLifeProvider timer runs before view is in hierarchy

- **File:** `Sources/DesktopCanvas/GameOfLifeProvider.swift`, line ~118-128
- **Description:** `init(canvas:)` calls `scheduleTimer()`. If `config.paused == false` (the default), the timer starts firing immediately on a background queue. Each tick calls `setNeedsDisplay(self.bounds)` on the main thread. The `draw(_:)` override checks `guard let drawable = currentDrawable` which returns `nil` (no superview → no window → no drawable), so the guard fails silently. But:
  - The timer is still firing every `1.0/generationsPerSecond` seconds (e.g., 33ms at 30 gen/s)
  - Each fire dispatches to main queue for `setNeedsDisplay`
  - This is wasted CPU/battery for the entire time between init and attach
  - In the CanvasWindow factory pattern (`layoutCanvases`), the provider is created THEN attached via CanvasRenderer.init → provider.attach(). There's a window of wasted timer ticks.
- **Impact:** Battery drain, unnecessary main-thread dispatches. Minor but real — especially if creating many GameOfLife canvases or if there's a delay between creation and application.
- **Recommended fix:** Move timer start to `attach()` and stop to `detach()`:

```swift
func attach(to superview: NSView, frame: NSRect) {
    superview.addSubview(self)
    startTimerIfNeeded()  // was in init, now here
}

func detach() {
    timer?.suspend()
    removeFromSuperview()
}

private func startTimerIfNeeded() {
    guard let config = canvas.gameOfLifeConfig, !config.paused else { return }
    // ... existing scheduleTimer logic, but only called when view is in hierarchy
}
```

---

### Bug #4: VideoProvider creates AVPlayerLayer at .zero frame on attach

- **File:** `Sources/DesktopCanvas/VideoProvider.swift`, line ~23-25
- **Description:** `attach(to:frame:)` is called by `CanvasRenderer.init` with `self.bounds` (which is `.zero` at init time). VideoProvider uses `frame` to position the AVPlayerLayer and placeholder. This creates a 0×0 layer briefly. The `update()` call in `CanvasWindow.layoutCanvases` fixes it when `renderer.frame = canvas.frame` triggers `setFrameSize` → `update()`.
- **Impact:** Brief 0×0 layer, no visual glitch since it's transparent and resized immediately. Low severity. However, if `update()` is called before the layer is added to a visible window, there could be a one-frame flash.
- **Recommended fix:** VideoProvider should not set the layer's frame until the player is ready. Or, defer layer creation to `update()` called after layout. Current behavior is acceptable for now but should be documented.

---

### Bug #5: CanvasRenderer omits `clipsToBounds = true` — content bleeding risk

- **File:** `Sources/DesktopCanvas/CanvasRenderer.swift`, line ~8-10
- **Description:** The comment says: "Do not set masksToBounds = true. It would clip the CAMetalLayer of MTKView subclasses while the renderer still has .zero bounds... causing the Metal render pipeline to silently fail." This is correct during the init-with-zero-bounds window, but the comment only addresses the transient init state. After `CanvasWindow.layoutCanvases` sets `renderer.frame = canvas.frame`, the bounds are correct and clipping SHOULD be enabled.
- **Impact:** If canvases do overlap (via hand-edited JSON or a bug in the overlap resolver), content from one canvas can bleed into another. The spec explicitly says "No two canvases may share any pixels" and R8 (macOS 14+ `clipsToBounds` default change) rates this as **HIGH severity**.
- **Recommended fix:** Enable `clipsToBounds = true` after layout:

```swift
override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    // Enable clipping once frame is non-zero
    if newSize.width > 0 && newSize.height > 0 {
        self.layer?.masksToBounds = true
    }
    provider?.update()
}
```

Or better: in `CanvasWindow.layoutCanvases`, after setting `renderer.frame`:

```swift
renderer.frame = canvas.frame
renderer.layer?.masksToBounds = true  // enable after layout
provider.update()
```

---

### Bug #6: 10M cell cap is a print-only warning — not enforced

- **File:** `Sources/DesktopCanvas/DesktopCanvas.swift`, line ~22-27
- **Description:** The total cell calculation is correct, but the result is only `print()`ed. The spec says "If total cell count exceeds 10 million, warn in editor (soft cap)" — which implies the warning should be surfaced to the caller, not just logged. More importantly, there's no enforcement in `GameOfLifeProvider.setupGrid()` — you could create a single canvas at 4000×3000 with cellSize=2 (2M cells × 1 canvas = 2M, fine) or cellSize=1 (12M cells, exceeds cap, silently allowed).
- **Impact:** Users can unknowingly create layouts that degrade to <10fps. No feedback beyond a console message they'll never see.
- **Recommended fix:** Return a result type or throw a warning:

```swift
public enum ApplyResult {
    case ok
    case warning(String)  // applied but exceeds soft cap
    case error(String)    // rejected (e.g., invalid layout)
}

public func apply(layout: CanvasLayout) -> ApplyResult {
    // ... existing checks ...
    if totalCells > 10_000_000 {
        return .warning("Total cell count (\(totalCells)) exceeds 10M limit. Performance may degrade.")
    }
    // ... apply ...
    return .ok
}
```

---

### Bug #7: `scheduleTimer()` uses `resume()` on a potentially suspended timer without checking state

- **File:** `Sources/DesktopCanvas/GameOfLifeProvider.swift`, line ~206-215
- **Description:** `scheduleTimer()` calls `newTimer.resume()` if `!config.paused`. But `scheduleTimer()` is called from `update()`, which can be called multiple times (e.g., on resize, reconfigure). Each call does `timer?.cancel(); timer = nil` then creates a new timer. That's fine. But `pause()` calls `timer?.suspend()` — if `scheduleTimer()` is then called, it replaces the timer. However, `resume()` calls `timer?.resume()` — if the timer was never suspended (i.e., `pause()` was called twice, or `resume()` is called after `scheduleTimer()` already started it), this will crash with a runtime exception: "resume() called on a source that was not suspended."
- **Impact:** Calling `resume()` twice or after a fresh `scheduleTimer()` will crash.
- **Recommended fix:** Track timer state explicitly:

```swift
private var isTimerRunning = false

private func scheduleTimer() {
    timer?.cancel()
    isTimerRunning = false
    // ... create timer ...
    if !config.paused {
        newTimer.resume()
        isTimerRunning = true
    }
    self.timer = newTimer
}

func pause() {
    guard isTimerRunning else { return }
    timer?.suspend()
    isTimerRunning = false
}

func resume() {
    guard !isTimerRunning else { return }
    timer?.resume()
    isTimerRunning = true
}
```

---

### Bug #8: `VideoProvider.loopObserver` uses `[weak self]` but captures `self.player` strongly in closure

- **File:** `Sources/DesktopCanvas/VideoProvider.swift`, line ~43-51
- **Description:**
```swift
loopObserver = NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: playerItem,
    queue: .main
) { [weak self] _ in
    guard let self, let player = self.player else { return }
    player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
        if finished { player.play() }
    }
}
```
The `player` is captured from `self.player` after the `guard let self`. This is fine — `self` is weak, and `player` is strong within the guard scope. However, if `detach()` is called between the `guard let` executing and the `seek(to:)` completing, `player` is still alive (strong reference in closure), so the seek succeeds and `play()` fires on a detached player. This plays audio/video into the void.
- **Impact:** Minor — a frame or two of audio after detach. No crash risk.
- **Recommended fix:** Check `self.playerLayer?.superlayer != nil` before calling `play()` to ensure the layer is still attached.

---

## 3. Architectural Concerns

### Concern #1: Canvas z-ordering is confusingly relevant despite "no overlap" spec

The design spec states: **"No two canvases may share any pixels."** If this is enforced, z-ordering is irrelevant — canvases never overlap, so draw order doesn't matter.

However, the current `CanvasWindow.layoutCanvases` adds subviews in array order via:
```swift
for canvas in canvases {
    guard let renderer = renderers[canvas.id] else { continue }
    contentView.addSubview(renderer)
}
```
This means the last canvas in the array is visually on top. If someone hand-edits a JSON preset to create overlaps, z-order matters.

**Assessment:** The z-ordering code is NOT dead weight — it's a safety net for hand-edited presets. But it's also insufficient: if we're going to handle overlaps at the window level, we should also detect and warn about them. Currently, overlapping canvases render without any warning or correction.

**Recommendation:** Add overlap detection at `apply()` time (Phase 6, runtime enforcement). The z-ordering stays as a fallback for cases where overlap is impossible to prevent (e.g., screen smaller than total canvas area).

---

### Concern #2: GameOfLifeProvider subclasses MTKView AND conforms to CanvasProvider — inappropriate coupling

`GameOfLifeProvider` IS an `MTKView`. This means:
- Every instance creates Metal resources in `init()` (device, pipelines, buffers, timers)
- If you create a provider but never call `attach()`, you've wasted Metal allocations
- The view owns its own lifecycle; the CanvasRenderer just sits on top

**Problem:** The spec says CanvasRenderer is the view wrapper — but GameOfLifeProvider IS the view. CanvasRenderer adds another layer of NSView wrapping that's redundant.

**Current hierarchy:**
```
CanvasWindow.contentView
  └── CanvasRenderer (NSView)
       └── GameOfLifeProvider (MTKView)  ← rendered content
```

The CanvasRenderer is a shell. Its only value is bridging the `CanvasProvider` protocol lifecycle (`attach`/`detach`/`update`/`setFrameSize`). But `GameOfLifeProvider` already subclasses NSView (via MTKView).

**Option A: Remove CanvasRenderer, make providers extend NSView directly**
- GameOfLifeProvider: MTKView subclass, conforms to CanvasProvider
- VideoProvider: NSView subclass, conforms to CanvasProvider
- CanvasWindow.contentView.addSubview(provider) directly
- Pros: One less view in the hierarchy. Simpler.
- Cons: VideoProvider currently uses AVPlayerLayer, not NSView/drawRect. Would need to wrap in an NSView.

**Option B: Keep CanvasRenderer, but make providers NOT subclass NSView**
- GameOfLifeProvider creates an MTKView internally, exposes it as a property
- CanvasRenderer.attach() adds the provider's view as a subview
- Pros: Clean separation. Providers are controller/logic, CanvasRenderer is view.
- Cons: More complexity, double wrapping.

**Recommendation:** Option A for Phase 6 cleanup. The current double-wrapping works but is inelegant. Not urgent — fix when touching these files for overlap work.

---

### Concern #3: ScreenManager owns NSApplication.run() — wrong ownership

This is covered in Bug #2 but deserves architectural discussion.

The current design:
```
ScreenManager.apply()
  → sets up NSApp
  → creates windows
  → calls NSApp.run()     ← blocks forever
  → returns on stop()     ← NSApp.terminate(nil)
```

The demo app (Phase 8-9) is a SwiftUI `@main App`. SwiftUI owns its own NSApplication.run() loop. There's no way to call ScreenManager.apply() from SwiftUI without it blocking the UI.

**Required architecture for Phases 8-11:**

```
@main App (owns NSApp)
  → DesktopCanvas.shared.apply(layout)
    → ScreenManager.apply(layout)
      → creates windows (does NOT call NSApp.run())
    → returns immediately
  → SwiftUI run loop runs normally
  → DesktopCanvas.shared.stop()
    → ScreenManager.stop()
      → closes windows (does NOT call NSApp.terminate())
```

The ScreenManager needs to be split into two modes:
1. **Library mode (current):** ScreenManager calls NSApp.run() — for use by simple CLI or script consumers
2. **Embedded mode (new):** ScreenManager assumes NSApp is already running — for use by demo app

**Recommendation:** Extract NSApp lifecycle to DesktopCanvas level:

```swift
// DesktopCanvas.swift
public func applyStandalone(layout: CanvasLayout) {
    // For CLI/script use: runs NSApp and blocks
    stop()
    let manager = ScreenManager()
    manager.apply(layout: layout)
    screenManager = manager
    saveLastUsedPreset(layout)
    NSApp.run()  // blocks until terminate
}

public func apply(layout: CanvasLayout) {
    // For embedded use (SwiftUI app): assumes NSApp is running
    stop()
    let manager = ScreenManager()
    manager.applyEmbedded(layout: layout)
    screenManager = manager
    saveLastUsedPreset(layout)
}
```

And ScreenManager's `apply(layout:)` should NOT call `NSApp.run()`. The `stop()` should NOT call `NSApp.terminate(nil)`.

---

### Concern #4: Metal resources allocated in init, not lazily — waste for paused/unused canvases

`GameOfLifeProvider.init(canvas:)` calls `setupMetal()` (creates pipeline, queue, buffers) and `setupGrid()` (allocates grid buffers + seeds). This all happens in init, before the view is ever attached to a window.

If a user creates a GameOfLife canvas in the editor but never applies it, or marks it as paused, the Metal resources are still allocated. For a 1000×1000 grid, that's 1MB for bufferA + 1MB for bufferB = 2MB per canvas.

**Recommendation:** Defer `setupMetal()` and `setupGrid()` to `attach()`. Store config in init, create resources on first attachment.

---

### Concern #5: Auto-save on every apply() — should this be explicit?

`DesktopCanvas.apply()` calls `saveLastUsedPreset(layout)` unconditionally. This means:
- Every apply() overwrites `_last_used.json`
- If you apply a test layout, then quit, the test layout auto-restores on next launch
- There's no distinction between "apply temporarily" and "save and apply"

The spec says: "On `apply(layout:)`, the layout is auto-saved as the last-used preset." So this matches the spec. But the spec also says: "Last-used preset path stored in `UserDefaults` key `lastAppliedPreset`" — which is NOT implemented. Currently it's always `_last_used.json` regardless of what was last explicitly saved.

**Recommendation:** Keep auto-save but also implement the `lastAppliedPreset` UserDefaults key so the demo app can load the user's explicitly-saved preset, not just whatever was last applied.

---

### Concern #6: `reallocateGrid` uses nested CPU loops for large grids

For a 1000×1000 grid resize, this is 1,000,000 iterations in Swift on a single thread. While this only happens on resize (infrequent), it blocks the caller (usually the main thread from `update()`).

**Recommendation:** For the common case where the grid is growing (adding rows/cols), use the GPU via a Metal blit command encoder:
- `blitEncoder.copy(from: oldBuffer, sourceOffset: 0, to: newBuffer, destinationOffset: 0, size: min(oldSize, newSize))`
- Only fall back to CPU copy for shrinking or when dimensions change in complex ways.

This is not urgent — resize is rare. Flag for Phase 14 polish.

---

### Concern #7: Single MTKView per canvas vs. single MTKView per screen

The spec's risk assessment (R7) recommended: "Single MTKView per screen with multiple render passes" as the long-term architecture, but the current approach uses one MTKView per canvas.

**Assessment:** For small numbers of canvases (≤5), the per-canvas approach is fine. For 20 canvas target, the per-screen approach is necessary. The spec acknowledges this.

**Recommendation:** Keep per-canvas for now, but plan the migration path. In Phase 6, when touching GameOfLifeProvider, add comments marking the pivot point for the per-screen refactor.

---

## 4. Revised Phase 6–12 Plan

### Phase 6: Overlap Prevention (Revised)

**Goal:** Make overlap impossible — at runtime, in the editor, and in JSON.

**Files to create/modify:**

#### 6.1 `Sources/DesktopCanvas/OverlapResolver.swift` (NEW)

```swift
import CoreGraphics

public enum OverlapResolver {
    
    /// Detects whether any two canvases in the layout overlap.
    /// Returns pairs of overlapping canvas IDs, or empty if none.
    public static func detectOverlaps(in canvases: [Canvas]) -> [(UUID, UUID)] {
        var overlaps: [(UUID, UUID)] = []
        for i in 0..<canvases.count {
            for j in (i+1)..<canvases.count {
                if canvases[i].frame.intersects(canvases[j].frame) {
                    overlaps.append((canvases[i].id, canvases[j].id))
                }
            }
        }
        return overlaps
    }
    
    /// Attempts to resolve overlaps by pushing `moving` away from `others`.
    /// Returns the resolved frame (possibly unchanged if no overlap).
    /// Strategy: shortest-axis push. Find the minimal translation that
    /// eliminates all intersections, preferring to push in the direction
    /// the canvas was already moving.
    public static func resolve(
        moving: Canvas,
        against others: [Canvas],
        preferredDirection: CGVector = .zero
    ) -> CGRect {
        var resolved = moving.frame
        let others = others.filter { $0.id != moving.id }
        
        for other in others {
            guard resolved.intersects(other.frame) else { continue }
            
            let intersection = resolved.intersection(other.frame)
            
            // Calculate push distances in all 4 directions
            let pushRight = other.frame.maxX - resolved.minX + 1
            let pushLeft = resolved.maxX - other.frame.minX + 1
            let pushUp = other.frame.maxY - resolved.minY + 1
            let pushDown = resolved.maxY - other.frame.minY + 1
            
            // Choose direction: prefer the direction of movement,
            // then fall back to shortest push
            var pushes: [(CGFloat, CGVector)] = [
                (pushRight, CGVector(dx: 1, dy: 0)),
                (pushLeft,  CGVector(dx: -1, dy: 0)),
                (pushUp,    CGVector(dx: 0, dy: 1)),
                (pushDown,  CGVector(dx: 0, dy: -1))
            ]
            
            // Sort by: prefer preferred direction, then shortest distance
            pushes.sort { a, b in
                let aDot = a.1.dx * preferredDirection.dx + a.1.dy * preferredDirection.dy
                let bDot = b.1.dx * preferredDirection.dx + b.1.dy * preferredDirection.dy
                if aDot != bDot { return aDot > bDot }
                return a.0 < b.0
            }
            
            resolved.origin.x += pushes[0].1.dx * pushes[0].0
            resolved.origin.y += pushes[0].1.dy * pushes[0].0
        }
        
        return resolved
    }
    
    /// Validates entire layout. Throws if any overlaps found.
    public enum ValidationError: Error, LocalizedError {
        case overlappingCanvases([(UUID, UUID)])
        
        public var errorDescription: String? {
            switch self {
            case .overlappingCanvases(let pairs):
                return "Layout contains \(pairs.count) overlapping canvas pair(s)"
            }
        }
    }
    
    public static func validate(_ canvases: [Canvas]) throws {
        let overlaps = detectOverlaps(in: canvases)
        if !overlaps.isEmpty {
            throw ValidationError.overlappingCanvases(overlaps)
        }
    }
}
```

#### 6.2 Runtime enforcement in `DesktopCanvas.swift` (MODIFY)

Add validation in `apply(layout:)` BEFORE creating windows:

```swift
public func apply(layout: CanvasLayout) -> ApplyResult {
    stop()
    
    // Validate no overlaps (hard requirement)
    let overlaps = OverlapResolver.detectOverlaps(in: layout.canvases)
    if !overlaps.isEmpty {
        return .error("Layout contains \(overlaps.count) overlapping canvas(es). Overlaps are not allowed.")
    }
    
    // Cell count check (soft cap, returns warning but still applies)
    let totalCells = /* ... existing calculation ... */
    
    let manager = ScreenManager()
    manager.applyEmbedded(layout: layout)
    self.screenManager = manager
    Self.saveLastUsedPreset(layout)
    
    if totalCells > 10_000_000 {
        return .warning("Total cell count (\(totalCells)) exceeds 10M limit.")
    }
    return .ok
}
```

#### 6.3 Runtime enforcement in `CanvasWindow.swift` (MODIFY)

Add overlap detection in `layoutCanvases` as a safety net:

```swift
func layoutCanvases(_ canvases: [Canvas]) {
    // Safety net: detect and log unexpected overlaps
    #if DEBUG
    let overlaps = OverlapResolver.detectOverlaps(in: canvases)
    if !overlaps.isEmpty {
        print("[CanvasWindow] WARNING: \(overlaps.count) overlapping canvas(es) detected. Overlaps should never occur.")
    }
    #endif
    
    // ... existing layout logic ...
}
```

#### 6.4 Editor-side push-out resolver (USED IN PHASE 9)

The `OverlapResolver.resolve(moving:against:preferredDirection:)` method is called by the editor when a user drags or resizes a canvas. The editor passes the drag direction as `preferredDirection` so the canvas pushes away from the cursor rather than snapping unpredictably.

**Edge cases to test:**
- Canvas pushed past screen edge → clamp to screen bounds
- Canvas pushed into a second overlapping canvas → iterate resolve until stable (max 10 iterations, then reject placement)
- Two canvases positioned exactly at the same frame → push the one being moved
- Canvas resized to be larger than screen → reject (with error feedback)

---

### Phase 7: Preset Persistence (Revised)

**Goal:** Full CRUD for named presets, plus fix the NSApp lifecycle dependency.

**Files to modify:**

#### 7.1 `Sources/DesktopCanvas/DesktopCanvas.swift` (MODIFY)

Add CRUD operations and fix NSApp ownership:

```swift
public final class DesktopCanvas {
    public static let shared = DesktopCanvas()
    private var screenManager: ScreenManager?
    
    // MARK: - Apply / Stop / Refresh
    
    /// Applies a layout. Assumes NSApp is already running (embedded mode).
    /// For CLI/standalone use, call `applyStandalone` instead.
    @discardableResult
    public func apply(layout: CanvasLayout) -> ApplyResult {
        stop()
        
        let overlaps = OverlapResolver.detectOverlaps(in: layout.canvases)
        if !overlaps.isEmpty {
            return .error("Overlapping canvases not allowed")
        }
        
        let totalCells = /* ... */ 
        
        let manager = ScreenManager()
        manager.applyEmbedded(layout: layout)
        self.screenManager = manager
        
        if totalCells > 10_000_000 {
            return .warning("Exceeds 10M cell limit")
        }
        return .ok
    }
    
    public func stop() {
        screenManager?.stop()
        screenManager = nil
    }
    
    public func refresh() {
        screenManager?.refresh()
    }
    
    // MARK: - Preset Management
    
    public func savePreset(_ layout: CanvasLayout, named name: String) throws {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        try layout.save(to: url)
    }
    
    public func loadPreset(named name: String) throws -> CanvasLayout {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        return try CanvasLayout.load(from: url)
    }
    
    public func deletePreset(named name: String) throws {
        let url = Self.presetsDirectory().appendingPathComponent("\(name).json")
        try FileManager.default.removeItem(at: url)
    }
    
    public func listPresets() -> [String] {
        let dir = Self.presetsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        return contents
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "_last_used.json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    
    // ... existing presetsDirectory(), lastUsedPresetURL(), etc. ...
}
```

#### 7.2 `Sources/DesktopCanvas/ScreenManager.swift` (MODIFY)

Split into `applyEmbedded` (no NSApp.run) and `applyStandalone` (with NSApp.run):

```swift
final class ScreenManager {
    private(set) var windows: [NSScreen: CanvasWindow] = [:]
    private var layout: CanvasLayout?
    private var displayObserver: NSObjectProtocol?
    
    /// For use when NSApp is already running (SwiftUI demo app)
    func applyEmbedded(layout: CanvasLayout) {
        self.layout = layout
        NSApplication.shared.setActivationPolicy(.accessory)
        
        for screen in NSScreen.screens {
            createWindow(for: screen)
        }
        
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }
    
    func stop() {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
            displayObserver = nil
        }
        for (_, window) in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        // NO NSApp.terminate — caller owns lifecycle
    }
    
    // ... existing createWindow, handleScreenChange, refresh unchanged ...
}
```

---

### Phase 8: Demo App — Foundation

**Goal:** A working SwiftUI app that can apply/stop layouts and edit canvases.

**Architecture decision:** The demo app IS the NSApplication. DesktopCanvas runs embedded (no NSApp.run()). This is Option A from the review prompt.

**Files to create:**

```
Sources/DesktopCanvasDemo/
├── main.swift                    ← @main App entry
├── AppDelegate.swift             ← NSApplicationDelegate
├── EditorView.swift             ← main split view
├── CanvasListView.swift         ← sidebar list
├── CanvasSettingsView.swift     ← detail/settings panel
```

**Key design decisions:**
- DesktopCanvas.shared.apply() is called from SwiftUI via a button
- `NSApplication.shared.setActivationPolicy(.regular)` so the demo app appears in Dock
- No NSApp.run() in DesktopCanvas — the SwiftUI `@main` handles it

#### 8.1 `main.swift`

```swift
import SwiftUI
import DesktopCanvas

@main
struct DesktopCanvasDemoApp: App {
    @StateObject private var editorState = EditorState()
    
    var body: some Scene {
        WindowGroup {
            EditorView()
                .environmentObject(editorState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}

class EditorState: ObservableObject {
    @Published var layout = CanvasLayout(
        name: "Untitled",
        canvases: []
    )
    @Published var selectedCanvasID: UUID?
    @Published var isApplied = false
    @Published var statusMessage: String?
    
    var selectedCanvas: Canvas? {
        layout.canvases.first { $0.id == selectedCanvasID }
    }
}
```

#### 8.2 `EditorView.swift` — main three-pane layout:

```
┌──────────────────────────────────────────────────┐
│ [Apply to Desktop] [Stop]  Status: ✓ Applied     │
├──────────┬───────────────────────┬───────────────┤
│ Canvas   │ Settings              │               │
│ List     │                       │               │
│          │ Type: [Game of Life▾] │               │
│ ┌──────┐ │ X: [100] Y: [200]    │ Grid Editor   │
│ │ GOL 1│ │ W: [400] H: [300]    │ (future Ph10) │
│ │ 400× │ │                       │               │
│ │ 300   │ │ Rule: [Conway▾]      │               │
│ └──────┘ │ Cell: [4]             │               │
│ ┌──────┐ │ Colors: ●●○○○         │               │
│ │Video1│ │ Speed: [====○] 30g/s  │               │
│ │ 640× │ │                       │               │
│ │ 480   │ │ [▶ Play] [⏸ Pause]   │               │
│ └──────┘ │                       │               │
│          │                       │               │
│ [+ Add]  │                       │               │
│ [Remove] │                       │               │
└──────────┴───────────────────────┴───────────────┘
```

#### 8.3 `CanvasListView.swift`

- `List($editorState.layout.canvases, selection: $editorState.selectedCanvasID)` 
- Each row shows: type icon (🎮/🎬), dimensions, mini preview
- `+` button adds default canvas (Conway, 300×300, centered on primary screen)
- `-` button removes selected with confirmation alert
- Drag-to-reorder via `.onMove`

---

### Phase 9: Demo App — Settings Panel

**Files to modify:** `CanvasSettingsView.swift` (extracted from EditorView)

#### 9.1 Position/Size fields
- X, Y, Width, Height as `TextField` with number formatter
- On submit: call `OverlapResolver.resolve(moving:against:)` with the canvases array minus the one being moved
- Visual feedback: red border if overlap can't be resolved

#### 9.2 Game of Life settings
- Rule set `Picker` with all 9 presets + "Custom"
- Custom: `TextField` with B/S notation, validated on each keystroke
- Cell size: `Slider` 2–64, step 1
- Colors: wrapped `NSColorWell` bridged to `CodableColor`
  - Since SwiftUI's `ColorPicker` binds to `Color` (which is iOS 15+/macOS 12+), bridge via `NSColor`: use `Color(nsColor:)` and `NSColor(red:green:blue:alpha:)`
- Speed: `Slider` 1–60, step 1
- Play/Pause: `Button` with SF Symbol `play.fill` / `pause.fill`

#### 9.3 Video settings
- File picker: `NSOpenPanel` via `NSViewRepresentable` wrapper
- Volume: `Slider` 0–100
- Loop: `Toggle`

#### 9.4 Real-time preview
- On settings change (debounced 200ms): call `DesktopCanvas.shared.refresh()`
- This pushes new config to the live desktop canvas immediately
- Only call `refresh()` if `isApplied == true`

#### 9.5 Canvas selection highlight (live overlay)
- When a canvas is selected in the editor and `isApplied == true`:
  - Show a semi-transparent overlay on the desktop highlighting the canvas bounds
  - Implementation: `CanvasWindow` gets a `highlightCanvas(id:)` method that adds/positions a semi-transparent border view
  - Auto-hide when selection changes or editor resigns key

---

### Phase 10: Demo App — Grid Editor

**Files to create:** `GridEditorView.swift`, `Sources/DesktopCanvas/BrushTool.swift`

#### 10.1 BrushTool (Swift — `Sources/DesktopCanvas/BrushTool.swift`)

This was deferred from Phase 1. It's pure Swift — no AppKit/Metal dependency. Used by the editor AND testable independently.

```swift
public enum BrushTool: String, CaseIterable, Codable {
    case pencil
    case line
    case rect
    case fill
    case random
}

public struct BrushEngine {
    public let gridWidth: Int
    public let gridHeight: Int
    
    public init(gridWidth: Int, gridHeight: Int) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
    }
    
    /// Toggle a single cell
    public func pencil(at col: Int, row: Int, in grid: inout [[Bool]]) {
        guard inBounds(col, row) else { return }
        grid[row][col].toggle()
    }
    
    /// Draw a Bresenham line from (x0,y0) to (x1,y1), setting all cells alive
    public func line(from: (Int, Int), to: (Int, Int), in grid: inout [[Bool]]) {
        var (x0, y0) = from
        let (x1, y1) = to
        
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        
        while true {
            setCell(x0, y0, alive: true, in: &grid)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }
    
    /// Fill a rectangle from (x0,y0) to (x1,y1) with alive cells
    public func rect(from: (Int, Int), to: (Int, Int), in grid: inout [[Bool]]) {
        let minX = max(0, min(from.0, to.0))
        let maxX = min(gridWidth - 1, max(from.0, to.0))
        let minY = max(0, min(from.1, to.1))
        let maxY = min(gridHeight - 1, max(from.1, to.1))
        
        for row in minY...maxY {
            for col in minX...maxX {
                grid[row][col] = true
            }
        }
    }
    
    /// Flood fill connected region starting at (col, row).
    /// Uses BFS (queue-based) — better stack depth than DFS for large grids.
    /// If the target cell is dead, fills connected dead region with alive.
    /// If the target cell is alive, kills connected alive region.
    public func fill(at col: Int, row: Int, in grid: inout [[Bool]]) {
        guard inBounds(col, row) else { return }
        
        let targetState = grid[row][col]
        let newState = !targetState
        
        var queue: [(Int, Int)] = [(col, row)]
        var visited = Set<Int>()
        visited.insert(row * gridWidth + col)
        
        while !queue.isEmpty {
            let (c, r) = queue.removeFirst()
            grid[r][c] = newState
            
            for (dc, dr) in [(0,1),(0,-1),(1,0),(-1,0)] {
                let nc = c + dc
                let nr = r + dr
                guard inBounds(nc, nr) else { continue }
                let key = nr * gridWidth + nc
                if !visited.contains(key) && grid[nr][nc] == targetState {
                    visited.insert(key)
                    queue.append((nc, nr))
                }
            }
        }
    }
    
    /// Fill entire grid with random seed at given density (0.0–1.0)
    public func random(density: Double = 0.5, in grid: inout [[Bool]]) {
        for row in 0..<gridHeight {
            for col in 0..<gridWidth {
                grid[row][col] = Double.random(in: 0...1) < density
            }
        }
    }
    
    /// Clear all cells
    public func clear(in grid: inout [[Bool]]) {
        for row in 0..<gridHeight {
            for col in 0..<gridWidth {
                grid[row][col] = false
            }
        }
    }
    
    private func inBounds(_ col: Int, _ row: Int) -> Bool {
        col >= 0 && col < gridWidth && row >= 0 && row < gridHeight
    }
    
    private func setCell(_ col: Int, _ row: Int, alive: Bool, in grid: inout [[Bool]]) {
        if inBounds(col, row) { grid[row][col] = alive }
    }
}
```

**BFS vs DFS for flood fill:** BFS (queue) is chosen because DFS (recursive) would stack-overflow on large grids (1M+ cells). BFS memory is O(width × height) in worst case — acceptable since grids are capped at 10M cells, and worst-case BFS on 10M entries is ~80MB (using `Set<Int>` for visited). Alternative: scanline fill (faster, lower memory) but more complex.

#### 10.2 `GridEditorView.swift`

- Canvas-based grid rendering using SwiftUI `Canvas` view
- Renders cells as small rectangles at the configured cell size
- Supports `MagnificationGesture` for zoom (1x–16x) and `DragGesture` for pan
- Tool palette: `Picker` bound to `BrushTool`
- Click/tap uses `.onTapGesture` → calls BrushEngine
- Drag uses `.gesture(DragGesture(...))` → tracks start/current position, calls line/rect on end

**Performance:** For large grids (e.g., 500×500 = 250K cells), rendering via SwiftUI `Canvas` with individual rectangles would be slow. Instead:
- Render to an offscreen bitmap (`CGContext`) and display as a single `Image`
- Update the bitmap on each edit (cheap for single-cell changes)
- Use `Canvas.draw(Image)` for the bitmap

**Real-time sync:** On any edit, debounce 100ms, then update `canvas.gameOfLifeConfig?.gridState` and call `DesktopCanvas.shared.refresh()`.

---

### Phase 11: Demo App — Preset Manager

**Files to create:** `PresetManagerView.swift`

- Sheet/modal presentation
- Left: list of preset names from `DesktopCanvas.shared.listPresets()`
- Right: preview of selected preset (canvas count, total cells)
- `[Save As...]` → `TextField` + save → `DesktopCanvas.shared.savePreset(named:)`
- `[Load]` → replaces current layout → `DesktopCanvas.shared.loadPreset(named:)`
- `[Delete]` → confirmation alert → `DesktopCanvas.shared.deletePreset(named:)`
- On load: apply to desktop if currently applied

**UserDefaults integration:**
- Store `lastAppliedPresetName` in `UserDefaults`
- On app launch: load that preset and apply (if it exists)
- This replaces the `_last_used.json` auto-save behavior

---

### Phase 12: Testing

**Goal:** Custom assertion harness, covering all pure-Swift logic.

**File:** `Tests/DesktopCanvasTests/main.swift`

#### 12.1 Harness design

```swift
import Foundation
import DesktopCanvas

var passed = 0
var failed = 0

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b {
        passed += 1
    } else {
        failed += 1
        print("✗ FAIL: \(msg) — expected \(b), got \(a) [\(file):\(line)]")
    }
}

func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("✗ FAIL: \(msg) [\(file):\(line)]")
    }
}

func assertThrows<T>(_ block: () throws -> T, _ msg: String, file: String = #file, line: Int = #line) {
    do {
        _ = try block()
        failed += 1
        print("✗ FAIL: \(msg) — expected throw but succeeded [\(file):\(line)]")
    } catch {
        passed += 1
    }
}

// --- Run tests ---

testCanvasLayoutRoundTrip()
testRuleSetParsing()
testBrushToolAlgorithms()
testOverlapResolver()
testCodableColorRoundTrip()
testCanvasMinSize()

// --- Summary ---
print("\n=== Test Results ===")
print("✓ \(passed) passed, ✗ \(failed) failed")
exit(failed > 0 ? 1 : 0)
```

#### 12.2 Test suites

**CanvasLayout round-trip:**
- Create layout with 2 canvases (1 GoL + 1 Video)
- Encode to JSON → decode → compare all fields
- Test empty layout
- Test layout with custom grid state

**RuleSet parsing:**
- `RuleSet(bSNotation: "B3/S23")` → Conway birth/survival
- `RuleSet(bSNotation: "B36/S23")` → HighLife
- `RuleSet(bSNotation: "B/S")` → Seeds (valid: birth empty, survival empty)
- `RuleSet(bSNotation: "invalid")` → nil
- `RuleSet(bSNotation: "B9/S9")` → valid (9 within 0-8 neighbor count — hmm, this is illegal in GoL, max neighbors is 8, but 9 should still parse)
- All 9 presets have valid bSNotation round-trip
- `conway.bSNotation == "B3/S23"`

**BrushTool algorithms:**
- Pencil: toggle a single cell, verify only that cell changes
- Line: horizontal (10,5)→(20,5), vertical (5,10)→(5,20), diagonal (0,0)→(5,5)
- Rect: fill 3×3 region, verify exactly 9 cells set
- Fill: create an L-shaped alive region, click inside dead region, verify only that region fills
- Fill: click alive cell, verify it kills the connected region
- Fill: click dead cell surrounded by dead, verify all dead cells fill
- Random at 50%: run 1000 cells, assert 300–700 alive (3-sigma for binomial)
- Clear: all cells dead after

**OverlapResolver:**
- Two non-overlapping canvases → detectOverlaps returns []
- Two overlapping canvases → detectOverlaps returns one pair
- Three canvases, two overlap → detectOverlaps returns one pair
- resolve() pushes canvas in preferred direction +1
- resolve() pushes canvas in preferred direction -1
- resolve() with no overlap → frame unchanged
- Canvas pushed past screen origin → test that returned frame has non-negative origin (handled by editor clamping, not resolver)

**CodableColor round-trip:**
- Encode → decode → compare RGBA values
- All static presets encode/decode correctly

**Canvas minimum size:**
- Create Canvas with 10×10 → frame is 32×32
- Decode JSON with 5×5 → frame is 32×32 (after Bug #1 fix)

#### 12.3 Package.swift update

Add test target:
```swift
.executableTarget(
    name: "DesktopCanvasTests",
    dependencies: ["DesktopCanvas"],
    path: "Tests/DesktopCanvasTests"
)
```

Run with: `swift run DesktopCanvasTests`

---

### Phase 13 & 14: Documentation & Polish (Unchanged)

These phases are straightforward. Key additions based on this review:
- Document the NSApp ownership model (embedded vs standalone)
- Document the clip-to-bounds behavior and why it's enabled after layout
- Add architecture diagram showing the full view hierarchy
- Performance profiling: verify single-frame GPU time with 10 GOL canvases + 2 videos

---

## 5. Dependency Graph (Revised)

```
Phase 6 (Overlap) ──────────────────────────────┐
    ↓                                            │
Phase 6.2 (fix NSApp lifecycle + DesktopCanvas)  │
    ↓                                            │
Phase 7 (Presets)                                │
    ↓                                            │
Phase 10a (BrushTool.swift in main Sources)      │
    ↓                                            │
Phase 8 (Demo foundation) ──→ Phase 9 (Settings) │
                                  ↓              │
                            Phase 10b (Grid Editor)
                                  ↓
                            Phase 11 (Preset Manager)
                                  ↓
                            Phase 12 (Tests)
```

**Parallelizable:**
- Phases 10a (BrushTool) can be done in parallel with Phases 6-7
- Phase 12 (Tests) can be started as soon as BrushTool, OverlapResolver, and RuleSet are stable — don't need to wait for demo app

**Critical path:** Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10b → Phase 11 → Phase 12

---

## 6. Risk Areas & Mitigation

### Risk: NSApp lifecycle refactor breaks existing behavior
- **Likelihood:** 3/5, **Impact:** 4/5
- **Mitigation:** Keep the old `applyStandalone` path as deprecated. New `apply()` is for embedded. Old callers continue to work. Mark old path as deprecated with warning comment.

### Risk: SwiftUI + AppKit coexistence issues
- **Likelihood:** 3/5, **Impact:** 3/5
- **Mitigation:** The demo app is pure SwiftUI. DesktopCanvas uses AppKit internally (NSWindow, MTKView). They coexist fine because DesktopCanvas windows are separate NSWindows at desktop level, not inside the SwiftUI view hierarchy. The only bridge point is `NSOpenPanel` for video file picker, which works via `NSViewRepresentable`.

### Risk: Grid editor performance for large grids
- **Likelihood:** 4/5, **Impact:** 2/5
- **Mitigation:** Use offscreen bitmap rendering for the grid preview (via `CGContext`), not individual SwiftUI rectangles. The bitmap approach renders 250K cells in a single `Image` draw — effectively free.

### Risk: Flood fill memory for worst-case grids
- **Likelihood:** 2/5, **Impact:** 2/5
- **Mitigation:** BFS with `Set<Int>` uses ~8 bytes per visited cell. 10M cells worst-case = 80MB. This is acceptable for a desktop app. If it becomes an issue, switch to scanline fill (constant memory).

---

## 7. Open Questions (Needs Human Decision)

1. **Should the existing `ScreenManager.apply()` + `NSApp.run()` path be kept for CLI/script users, or removed entirely?** If there are scripts using DesktopCanvas as a standalone, removing it is a breaking change. Recommendation: keep as deprecated overload `applyStandalone`.

2. **Should auto-save on apply() be removed in favor of explicit save?** The spec says yes (auto-save). But the current behavior overwrites `_last_used.json` on every apply — including temporary/test applies. Recommendation: keep auto-save but change it to only save when explicitly named (Phase 11 behavior). The `_last_used.json` becomes the "last explicitly saved named preset", not "last applied layout".

3. **Should the per-canvas MTKView approach be refactored to per-screen now (Phase 6) or later (Phase 14+)?** The spec's risk assessment (R7) strongly recommends per-screen for 10+ canvases. But refactoring now would delay the demo app. Recommendation: defer to Phase 14+ polish. Add a `// MARK: Future — single MTKView per screen` comment block in GameOfLifeProvider.

4. **Should the overlap resolver push canvases, reject placement, or both?** The spec says "snap to nearest non-overlapping position." But what if no non-overlapping position exists (e.g., screen is 1920×1080 and user tries to place a 2000×2000 canvas)? Recommendation: push first, clamp to screen bounds, if still overlapping → reject with red flash.

5. **Should the demo app live in `Sources/DesktopCanvasDemo/` or `Examples/DesktopCanvasDemo/`?** The Package.swift already has a `DesktopCanvasTest` executable target at `Sources/`. Recommendation: use `Sources/DesktopCanvasDemo/` for consistency with Package.swift conventions.

---

## 8. Research Directions (Spike Before Building)

### 8.1 SwiftUI `Canvas` view performance with large grids
**Question:** Can SwiftUI's `Canvas` view render 500×500 individual rectangles at 60fps?
**Spike:** Create a standalone SwiftUI app with a `Canvas` view rendering a 500×500 grid of colored rectangles. Measure frame time with Instruments.
**Fallback:** If too slow, use offscreen `CGContext` bitmap → `Image` approach.

### 8.2 `NSColorWell` in SwiftUI on macOS 13+
**Question:** Does `ColorPicker` work as a drop-in for `CodableColor` bindings, or do we need `NSColorWell` via `NSViewRepresentable`?
**Spike:** Create a SwiftUI form with `ColorPicker` bound to a CodableColor-backed state. Test on macOS 13 (our deployment target). Verify the color picker doesn't trigger unwanted NSColor-space conversions.

### 8.3 `AVPlayer.seek(to:)` gap measurement on target hardware
**Question:** The S0.5 spike showed ~55ms gap. Does this vary by video codec (H.264 vs H.265 vs ProRes)?
**Spike:** Test the loop gap with 3 common video formats at 1080p and 4K. If H.265 has significantly larger gaps, document the recommended format.

### 8.4 Multiple CanvasWindow + Mission Control interaction
**Question:** With 2 screens and 5 canvases each, does Mission Control show any artifacts?
**Spike:** Create 2 CanvasWindows (one per screen), place 5 GameOfLife canvases each. Enter Mission Control. Screenshot. Verify no weird tiles.

---

## 9. Summary of Recommended Fixes (Priority-Ordered)

| Priority | Bug/Concern | Action |
|---|---|---|
| **P0** | ScreenManager.stop() kills NSApp permanently | Extract NSApp lifecycle from ScreenManager. Add `applyEmbedded()` method. |
| **P0** | No overlap detection at runtime | Add `OverlapResolver.validate()` call in `DesktopCanvas.apply()`. |
| **P1** | Canvas JSON decode bypasses 32×32 min | Apply `max(..., 32)` in `init(from decoder:)`. |
| **P1** | 10M cell cap is print-only | Return `ApplyResult` enum with `.warning` case. |
| **P1** | GameOfLifeProvider timer runs before attach | Move `scheduleTimer()` from `init` to `attach()`. |
| **P1** | `clipsToBounds` missing on CanvasRenderer | Enable after non-zero frame set (in `setFrameSize` or `layoutCanvases`). |
| **P2** | `resume()` on unsuspended timer crashes | Track timer state with `isTimerRunning` flag. |
| **P2** | `reallocateGrid` CPU loops for large grids | Document as acceptable; add GPU blit path in polish phase. |
| **P2** | `VideoProvider.loopObserver` plays after detach | Check `playerLayer?.superlayer != nil` in completion handler. |
| **P3** | Auto-save overwrites on every apply | Change to save only explicitly named presets via Phase 11. |
| **P3** | Double-wrapped view hierarchy (CanvasRenderer + Provider) | Consider flattening in Phase 6 — not urgent. |

---

*End of review. Ready for Phase 6 implementation upon approval of architectural decisions in Section 7.*