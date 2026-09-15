import AppKit
import GhostTrail

print("[GhostTrailDemo] Starting...")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let ghostTrail = GhostTrail()
print("[GhostTrailDemo] GhostTrail instance created")

var isRunning = false

@objc final class TrailController: NSObject {
    static let shared = TrailController()

    @objc func toggleTrail() {
        if isRunning {
            print("[GhostTrailDemo] Stopping trail")
            GhostTrail.current?.stop()
            isRunning = false
            toggleItem.title = "Start"
        } else {
            print("[GhostTrailDemo] Starting trail")
            isRunning = ghostTrail.start()
            toggleItem.title = isRunning ? "Stop" : "Start"
        }
    }

    @objc func applySubtle() {
        restartWith(GhostTrail().preset(.subtle))
    }

    @objc func applyDefault() {
        restartWith(GhostTrail())
    }

    @objc func applyDramatic() {
        restartWith(GhostTrail().preset(.dramatic))
    }

    @objc func applyRetro() {
        restartWith(GhostTrail().preset(.retro))
    }

    @objc func applyNeon() {
        restartWith(GhostTrail().preset(.neon))
    }

    @objc func applyGlass() {
        restartWith(GhostTrail().preset(.glass))
    }

    private func restartWith(_ newTrail: GhostTrail) {
        GhostTrail.current?.stop()
        isRunning = newTrail.start()
        toggleItem.title = isRunning ? "Stop" : "Start"
    }
}

let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
if let button = statusItem.button {
    button.image = NSImage(systemSymbolName: "rectangle.trailinghalf.inset.filled.arrow.trailing",
                           accessibilityDescription: "GhostTrail")
    button.toolTip = "GhostTrail"
}

let menu = NSMenu()

let toggleItem = NSMenuItem(title: "Start", action: #selector(TrailController.toggleTrail), keyEquivalent: "")
toggleItem.target = TrailController.shared
menu.addItem(toggleItem)

menu.addItem(NSMenuItem.separator())

let subtleItem = NSMenuItem(title: "Subtle", action: #selector(TrailController.applySubtle), keyEquivalent: "1")
subtleItem.target = TrailController.shared
menu.addItem(subtleItem)

let defaultItem = NSMenuItem(title: "Default", action: #selector(TrailController.applyDefault), keyEquivalent: "2")
defaultItem.target = TrailController.shared
menu.addItem(defaultItem)

let dramaticItem = NSMenuItem(title: "Dramatic", action: #selector(TrailController.applyDramatic), keyEquivalent: "3")
dramaticItem.target = TrailController.shared
menu.addItem(dramaticItem)

let retroItem = NSMenuItem(title: "Retro", action: #selector(TrailController.applyRetro), keyEquivalent: "4")
retroItem.target = TrailController.shared
menu.addItem(retroItem)

let neonItem = NSMenuItem(title: "Neon", action: #selector(TrailController.applyNeon), keyEquivalent: "5")
neonItem.target = TrailController.shared
menu.addItem(neonItem)

let glassItem = NSMenuItem(title: "Glass", action: #selector(TrailController.applyGlass), keyEquivalent: "6")
glassItem.target = TrailController.shared
menu.addItem(glassItem)

menu.addItem(NSMenuItem.separator())

menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

statusItem.menu = menu

print("[GhostTrailDemo] Menu bar item created. Look for arrow icon in menu bar.")
print("[GhostTrailDemo] Click it and press 'Start', then drag any window.")
app.run()