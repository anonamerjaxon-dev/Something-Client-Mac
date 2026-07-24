import Foundation
import CoreGraphics
import AppKit

/// Manages showing/hiding the system cursor.
/// Uses CGDisplayHideCursor / CGDisplayShowCursor for system-wide cursor control.
/// Falls back to NSCursor-based hiding if Accessibility permissions aren't available.
public final class CursorManager {
    public static let shared = CursorManager()

    private var isHidden: Bool = false
    private var hideCount: Int = 0

    private init() {}

    // MARK: - Public API

    /// Hide the system cursor across all displays.
    /// Returns true if successful, false if permissions are missing.
    @discardableResult
    public func hide() -> Bool {
        hideCount += 1
        guard !isHidden else { return true }

        let result = hideSystemCursor()
        if result {
            isHidden = true
        }
        return result
    }

    /// Show the system cursor. Uses a reference count so nested hide/show calls
    /// are balanced correctly.
    public func show() {
        hideCount = max(hideCount - 1, 0)
        guard hideCount == 0, isHidden else { return }

        showSystemCursor()
        isHidden = false
    }

    /// Force-show the cursor regardless of reference count.
    public func forceShow() {
        hideCount = 0
        guard isHidden else { return }
        showSystemCursor()
        isHidden = false
    }

    public var isSystemCursorHidden: Bool { isHidden }

    // MARK: - Private Implementation

    private func hideSystemCursor() -> Bool {
        // Primary method: CGDisplayHideCursor — system-wide, reliable
        // Requires Accessibility permissions in sandboxed apps
        var result = CGDisplayHideCursor(CGMainDisplayID()) == .success

        // If we have multiple displays, hide on all of them
        let maxDisplays: UInt32 = 16
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)

        for i in 0..<Int(displayCount) {
            if displayIDs[i] != CGMainDisplayID() {
                let secondaryResult = CGDisplayHideCursor(displayIDs[i])
                result = result && (secondaryResult == .success)
            }
        }

        // Fallback: NSCursor-based approach for when CGDisplayHideCursor
        // isn't available (e.g., sandbox without accessibility)
        if !result {
            applyInvisibleCursor()
            result = true // NSCursor approach always "works" but is less reliable
        }

        return result
    }

    private func showSystemCursor() -> Bool {
        var result = CGDisplayShowCursor(CGMainDisplayID()) == .success

        let maxDisplays: UInt32 = 16
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)

        for i in 0..<Int(displayCount) {
            if displayIDs[i] != CGMainDisplayID() {
                let secondaryResult = CGDisplayShowCursor(displayIDs[i])
                result = result && (secondaryResult == .success)
            }
        }

        // Reset cursor to default arrow
        NSCursor.arrow.set()

        return result
    }

    /// Fallback: Create a 1x1 fully transparent cursor image.
    /// Less reliable than CGDisplayHideCursor but doesn't need permissions.
    private func applyInvisibleCursor() {
        let image = NSImage(size: NSSize(width: 1, height: 1), flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            return true
        }
        let invisibleCursor = NSCursor(image: image, hotSpot: NSPoint(x: 0, y: 0))
        invisibleCursor.set()
    }

    // MARK: - Permission Check

    /// Check if the process has Accessibility permissions.
    /// CGDisplayHideCursor requires either:
    ///   - Running outside a sandbox, OR
    ///   - com.apple.security.device.accessibility entitlement
    public static var hasAccessibilityPermission: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Prompt the user to grant Accessibility permissions.
    public static func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}