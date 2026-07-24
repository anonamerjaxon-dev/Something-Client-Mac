# CursorTrail V2 — Brainstorming & Architecture

## Problems to Solve

### 1. Mission Control / Show Windows (F3)
When the user presses F3 or uses the "Show Windows" gesture, macOS's window server
takes over the compositor. All windows (including the trail at `.screenSaver` level)
get pushed up into the Mission Control layout. The trail disappears from the cursor.

**Root Cause**: The trail window participates in the window server's Exposé/Mission
Control animations. `.screenSaver` level (1000) is high, but not high enough to
escape Mission Control's compositor takeover.

### 2. Full Screen Apps
When entering a full-screen app, the trail window moves to the app's space but
may get occluded or the window level may not be respected.

### 3. Hiding the Original macOS Cursor
For the planned "Customizable Cursor" module, we need to be able to hide the
system cursor at any time, system-wide, and keep it hidden while the trail
(and eventual custom cursor) runs.

---

## Proposed Solutions

### A. Window Level — Climb Higher

| Level | Value | Behavior |
|---|---|---|
| `.normal` | 0 | Regular windows |
| `.floating` | 3 | Palettes, panels |
| `.popUpMenu` | 101 | Menus |
| `.screenSaver` | 1000 | **Current** — still below Mission Control |
| `.statusBar` | 1000-2000 | Menu bar region |
| `.cursorWindow` | ~2147483620 | System cursor level — **highest possible** |

**Recommendation**: Use `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))`
or a custom level like `NSWindow.Level(rawValue: 2147483620)`.

This is the level macOS uses for the actual cursor. At this level, the window
should render above Mission Control.

**Caveat**: At this level, the window might intercept cursor events. We need to
ensure `ignoresMouseEvents = true` is still respected.

### B. Collection Behaviors — Opt Out of Mission Control

Current behaviors:
```swift
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

Add these:
```swift
collectionBehavior = [
    .canJoinAllSpaces,       // Follows across Spaces
    .fullScreenAuxiliary,    // Visible in full-screen apps
    .stationary,             // Unaffected by Exposé/Mission Control ← KEY
    .ignoresCycle,           // Not in Cmd+Tab cycle
    .transient,              // Doesn't appear in Exposé
]
```

**`.stationary`** is the critical one — it tells the window server that this
window should not be moved during Mission Control / Exposé animations.

### C. Mission Control Detection — Fallback

Even with `.stationary`, we can add a safety net by detecting when Mission
Control activates and re-raising the window:

```swift
// Option 1: NSWorkspace notifications
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.activeSpaceDidChangeNotification,
    ...
)

// Option 2: CGWindowLevel observation via CGWindowList
// Periodically check if our window is still at the top

// Option 3: Distributed notification center
DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.expose.frontShow"),
    ...
)
```

### D. Cursor Hiding — CGDisplayHideCursor

The most reliable system-wide cursor hiding API:

```swift
import CoreGraphics

// Hide the cursor system-wide
CGDisplayHideCursor(CGMainDisplayID())

// Show it again
CGDisplayShowCursor(CGMainDisplayID())
```

**Requirements**:
- The app must have **Accessibility** permissions
- Need to add entitlements: `com.apple.security.device.accessibility`
- Or: run the app as a trusted accessibility process

**Alternative (no permissions needed)**: Set a custom 1x1 transparent cursor
image via `NSCursor`. This is less reliable but doesn't need permissions.

```swift
let invisibleCursor = NSCursor(
    image: NSImage(size: NSSize(width: 1, height: 1), flipped: false) { _ in true },
    hotSpot: NSPoint(x: 0, y: 0)
)
invisibleCursor.set()
```

But this only works while the app is active. For a background daemon approach,
`CGDisplayHideCursor` is the way to go.

### E. Full Screen Apps

The current `.fullScreenAuxiliary` behavior should handle this, but it may need
to be combined with `.stationary` to prevent the window from being managed by
the full-screen space transition.

---

## Architecture Decisions

### Option 1: Stay in Swift (SPM Package)
- Keep the same Package.swift structure
- Add new CursorTrailV2 target or extend existing
- Pros: Same toolchain, same language, easy integration
- Cons: Swift's NSWindow API has limitations at very high window levels

### Option 2: Hybrid Swift + Objective-C
- Use Objective-C for the window-level hacks (CGWindowLevel, CGDisplayHideCursor)
- Swift for the rendering and API
- Pros: More control over low-level window server APIs
- Cons: Mixed-language project, more complex

### Option 3: Pure C/Objective-C Daemon
- A background daemon that draws directly to the framebuffer/compositor
- Uses CGDisplay APIs, CoreGraphics, Metal
- Pros: Maximum control, no window server involvement
- Cons: Much more complex, harder to maintain

**Recommendation**: **Option 1 (Swift)** with the modifications described above.
The key changes are:
1. Higher window level (cursor level)
2. `.stationary` collection behavior
3. `CGDisplayHideCursor`/`CGDisplayShowCursor` for cursor management
4. Mission Control notification listener as fallback

---

## Proposed API for V2

```swift
// Updated CursorTrail with cursor management
let trail = CursorTrail()
    .color(.rainbow)
    .thickness(12)
    .length(10)
    .hideSystemCursor(true)    // NEW: hide the original cursor
    .start()

// Or control cursor separately
CursorTrail.hideSystemCursor()
CursorTrail.showSystemCursor()

// Check state
CursorTrail.isSystemCursorHidden  // Bool
```

## Key Files to Create

1. `CursorTrailV2.swift` — Updated main class with cursor hiding + window fixes
2. `CursorManager.swift` — Cursor hiding/showing abstraction
3. `TrailWindowV2.swift` — Updated window with corrected level + behaviors
4. `MissionControlObserver.swift` — Detect and handle Mission Control
5. `CursorTrailV2.entitlements` — Accessibility permissions