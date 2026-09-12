# DesktopCanvas Phase 0 — Research Spike Report

**Date:** 2026-09-12
**macOS version tested:** macOS Tahoe 26.6.2 (Build 25G83)

---

## S0.1: Desktop Window Level

| Metric | Result |
|---|---|
| Actual `CGWindowLevelForKey(.desktopIconWindow)` | `-2147483603` |
| Actual `CGWindowLevelForKey(.desktopWindow)` | `-2147483623` |
| `kCGDesktopIconWindowLevel - 1` (-2147483604) | PASS — behind icons, icons clickable, survives Spaces. FAIL: disappears in Mission Control |
| `kCGDesktopWindowLevel - 1` (-2147483624) | PASS — behind icons, icons clickable, survives Spaces. FAIL: disappears in Mission Control |
| `kCGDesktopIconWindowLevel` raw (-2147483603) | **PASS — ALL CRITERIA MET** |
| `kCGDesktopWindowLevel` raw (-2147483623) | PASS — behind icons, icons clickable. FAIL: disappears in Mission Control |
| Hardcoded `-1000` | FAIL — covers desktop icons (normal-window behavior). Also fails MC + Show Desktop |
| Hardcoded `-2147483622` | PASS — behind icons. FAIL: disappears in Mission Control |
| Icons clickable | YES (for all desktop-level windows: 1, 2, 3, 4, 6) |
| Appears in Mission Control | NO for tests 1, 2, 4, 6. YES for test 3 (desired). Test 5: NO |
| Survives Space switch | YES (for all desktop-level windows) |
| Show Desktop (F11) behavior | Test 5 disappears. Test 3 survives (part of "works completely") |

**Winner level (rawValue):** `-2147483603` — `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))`

**Notes:**
- `kCGDesktopIconWindowLevel` (raw, no offset) is the only level that satisfies ALL criteria: behind icons, icons clickable, persists in Mission Control, survives Spaces, survives Show Desktop.
- The `-1` variants work behind icons but vanish from Mission Control — useful to know but not our target.
- `kCGDesktopWindowLevel` (raw) also works behind icons but vanishes from MC.
- Hardcoded `-1000` is way too high — acts like a normal window on top of icons.
- macOS 26.6.2 has an autorelease pool crash bug when desktop-level NSWindows are created/destroyed with `NSApplication.run()` / `CFRunLoopRun()`. This does NOT block the architecture: in production, DesktopCanvas creates ONE persistent window and keeps it alive for the app's lifetime. Spike tests work around this with `exit(0)`.

---

## S0.2: MTKView + AVPlayerLayer Compositing

| Metric | Result |
|---|---|
| No flickering | YES |
| No boundary artifacts | YES |
| 60fps maintained | YES |
| Z-order correct (both visible) | YES |
| Desktop video integration test | **PASS** — AVPlayerLayer at desktop window level works as full-screen video wallpaper |

**Notes:**
- MTKView required explicit `isPaused = false`, `enableSetNeedsDisplay = false`, and `clearColor` set in init (not overridden in `draw(in:)`) to render correctly.
- Combined test: AVPlayerLayer playing Minecraft MP4 at `kCGDesktopIconWindowLevel` with `resizeAspectFill` — video plays behind icons, icons clickable, survives Mission Control and Spaces. Architecture confirmed.
- `MTKView.draw(_:)` (NSView CPU drawing) does NOT work for Metal — must use `MTKViewDelegate.draw(in:)`.

---

## S0.3: Permissions

| Metric | Result |
|---|---|
| Screen Recording dialog | NO |
| Accessibility dialog | NO |
| CGDisplayHideCursor triggers permission | NO — CGError 0 (success) without any dialog |
| Desktop window renders without permissions | YES — no dialogs, no System Settings entries added |

**Notes:**
- `CGDisplayHideCursor(CGMainDisplayID())` succeeds without triggering Screen Recording or Accessibility permission on macOS 26.6.2.
- Desktop-level window creation requires zero special permissions.
- DesktopCanvas does NOT use cursor hiding, so this is informational only — confirms we won't hit unexpected permission gates.

---

## S0.4: Game of Life Metal Compute

| Metric | Result |
|---|---|
| Conway patterns emerge | YES — gliders, blinkers, blocks from random seed |
| FPS at 500×500 | YES — smooth 60fps |
| Buffer swap flicker | NO — double-buffer ping-pong clean |
| Compute dispatch works correctly | YES — 16×16 threadgroups, grid-wide dispatch |
| Toroidal wrapping correct at edges | YES — patterns wrap cleanly |

**Notes:**
- Metal compute (kernel + fragment) works correctly with inline shader source.
- Retina display scaling: fragment shader receives pixel coordinates (`drawableSize`), not points (`bounds`). Cell size and view dimensions must be in pixels.
- `contentScaleFactor` is deprecated on NSView — use `drawableSize.width / bounds.width` instead.
- Separate `.metal` file is unused (shader embedded in Swift). Production: use `.metal` file with bundle resource build phase.

---

## S0.5: AVPlayer Loop

| Metric | Result |
|---|---|
| Visible gap at boundary | YES — ~55ms (~3 frames at 60fps) |
| Gap frame count (total across 20 loops) | 19 (every loop had same seek latency) |
| Average gap duration | 0.055s |
| Two-player crossfade needed | NO — gap is barely noticeable, not worth the complexity for now |

**Notes:**
- `actionAtItemEnd = .none` + `seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)` works reliably.
- The 55ms gap is the `seek(to:)` completion handler latency, consistent across all loops.
- Barely perceptible — acceptable for a desktop canvas. Two-player crossfade can be added later if needed.

---

## Conclusion

| Question | Answer |
|---|---|
| Can we proceed with desktop-window approach? | **YES** |
| If NO, which fallback is recommended? | N/A |
| Any other blockers? | macOS 26.6.2 beta has autorelease pool crash when desktop NSWindows are destroyed — mitigated by: production creates one persistent window, never destroys it during runtime |
| Recommended window level integer for production: | **-2147483603** — `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))` |

---

## Lessons Learned: Spike Mistakes & Production Rules

### 1. NSView.draw(\_:) vs MTKViewDelegate.draw(in:)
**Mistake:** Overrode `NSView.draw(_:)` expecting Metal to render. MTKView bypasses AppKit's draw cycle — only `MTKViewDelegate.draw(in:)` triggers the Metal render loop. MTKView also needs `isPaused = false` and `enableSetNeedsDisplay = false` after setting the delegate.
**Rule:** Always implement `MTKViewDelegate` for Metal rendering. `NSView.draw(_:)` is a no-op for MTKView.

### 2. MTKView.clearColor overrides render-pass clear
**Mistake:** Set `self.clearColor = black` in init, then tried `rpDesc.colorAttachments[0].clearColor = red` in `draw(in:)`. MTKView configures the render pass descriptor *before* `draw(in:)` fires, so the black overrode the red.
**Rule:** Set `clearColor` once in init. Don't fight it in the render loop.

### 3. Retina: bounds (points) != drawableSize (pixels)
**Mistake:** Passed `bounds.width`/`bounds.height` to Metal fragment shader uniforms, but `in.position` in Metal is in pixels. On 2x displays, half the content was out-of-bounds (rendered as dark gray).
**Rule:** Always use `drawableSize` for Metal uniform math. Never mix AppKit point-space values with Metal pixel-space coordinates. `contentScaleFactor` is deprecated — derive scale from `drawableSize.width / bounds.width` if needed.

### 4. NSWindow z-order races with Finder
**Mistake:** Multiple window creation/destruction during level testing caused Finder icon z-order jitter. A single persistent window with `order(.below, relativeTo: 0)` avoids the race entirely.
**Rule:** One persistent desktop window, ordered once, kept alive for app lifetime.

### 5. Loop gap: cmTime vs wall-clock time
**Mistake:** Computed gap as `CMTimeGetSeconds(endTime) - lastLoopTime` where `lastLoopTime` was `.zero`, producing ~40s "gaps" (the full video duration).
**Rule:** Gap = `Date().timeIntervalSince(playbackEndTime)` — measure real elapsed time around `seek(to:)`, not CMTime deltas.

### 6. SwiftPM: inline Metal vs .metal file
**Mistake:** Created a separate `game_of_life.metal` file but used inline string shaders in Swift. The `.metal` file went unused, producing a build warning.
**Rule:** Pick one. Inline strings are fine for spikes. Production: use `.metal` files with proper build-phase resource inclusion for edit-then-reload workflow.

### 7. Window content rect includes title bar
**Mistake:** Set `contentRect: NSRect(x: 0, y: 0, width: 1000, height: 1000)` on a titled window — the title bar consumed ~28px from the content area, clipping the Metal grid.
**Rule:** Use `window.setContentSize(NSSize(width: 1000, height: 1000))` to guarantee exact content dimensions, or make the window borderless.