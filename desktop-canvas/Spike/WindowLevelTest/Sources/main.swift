import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let iconLevel = CGWindowLevelForKey(.desktopIconWindow)

print("=== S0.1 Desktop Window Level ===\n")
print("Winner: kCGDesktopIconWindowLevel raw = \(iconLevel)")
print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("Screen: \(NSScreen.main!.frame)\n")

let screen = NSScreen.main!
let window = NSWindow(
    contentRect: screen.frame,
    styleMask: .borderless,
    backing: .buffered,
    defer: false
)
window.level = NSWindow.Level(rawValue: Int(iconLevel))
window.isOpaque = false
window.hasShadow = false
window.ignoresMouseEvents = true
window.backgroundColor = NSColor.systemRed
window.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary,
    .stationary,
    .transient,
    .ignoresCycle
]
window.contentView?.wantsLayer = true
window.contentView?.clipsToBounds = true

let label = NSTextField(labelWithString: "DesktopCanvas S0.1 — Winner: kCGDesktopIconWindowLevel")
label.font = NSFont.boldSystemFont(ofSize: 24)
label.textColor = .white
label.alignment = .center
label.frame = NSRect(x: 0, y: screen.frame.midY - 20, width: screen.frame.width, height: 40)
label.wantsLayer = true
label.clipsToBounds = true
window.contentView?.addSubview(label)

window.order(.below, relativeTo: 0)

DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
    window.close()
    exit(0)
}

app.run()