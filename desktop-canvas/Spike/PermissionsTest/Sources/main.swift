import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

class PermissionsDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== S0.3 Permissions Check ===\n")

        print("1. Checking CGDisplayHideCursor permission requirement...")
        print("   Calling CGDisplayHideCursor(CGMainDisplayID()) in 2 seconds...")
        print("   Watch for any permission dialogs!\n")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let result = CGDisplayHideCursor(CGMainDisplayID())
            print("   CGDisplayHideCursor returned: \(result) (0 = success)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                CGDisplayShowCursor(CGMainDisplayID())
                print("   Cursor restored.")

                print("\n2. Creating desktop-level NSWindow...")
                self.createDesktopWindow()

                print("\n=== Summary Questions ===")
                print("A) Did CGDisplayHideCursor trigger any permission dialog?")
                print("   - Screen Recording: check System Settings > Privacy > Screen Recording")
                print("   - Accessibility: check System Settings > Privacy > Accessibility")
                print("B) Did the desktop window trigger any permission dialog?")
                print("C) Did the window render without granting any special permissions?")
                print("\nObserve and record findings in REPORT.md.")
            }
        }
    }

    func createDesktopWindow() {
        guard NSScreen.main != nil else { return }
        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "S0.3: Desktop Level Test Window"
        window.level = level
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.backgroundColor = NSColor.green.withAlphaComponent(0.3)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .transient,
            .ignoresCycle
        ]
        window.contentView?.wantsLayer = true
        window.contentView?.clipsToBounds = true
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let delegate = PermissionsDelegate()
app.delegate = delegate
app.run()