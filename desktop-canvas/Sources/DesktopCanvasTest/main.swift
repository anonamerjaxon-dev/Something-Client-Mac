import AppKit
import DesktopCanvasModel

print("=== DesktopCanvasModel Phase 5 Smoke Test ===")
print("Applying Conway's Game of Life to desktop...")
print("Should see green cells behind your desktop icons.")
print("Test runs for 5 seconds, then exits.\n")

let golConfig = GameOfLifeConfig(
    ruleSet: RuleSet.presets[0],
    cellSize: 4,
    aliveColor: CodableColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1.0),
    deadColor: CodableColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0),
    marginColor: CodableColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0),
    generationsPerSecond: 30
)

guard let screen = NSScreen.main else {
    print("ERROR: No screen found")
    exit(1)
}

let canvas = CanvasModel(
    type: .gameOfLife,
    frame: screen.frame,
    gameOfLifeConfig: golConfig
)

let layout = CanvasModelLayout(name: "Phase 5 Test", canvases: [canvas])
DesktopCanvasModel.shared.apply(layout: layout)

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    print("\nTest complete. Stopping...")
    DesktopCanvasModel.shared.stop()
}