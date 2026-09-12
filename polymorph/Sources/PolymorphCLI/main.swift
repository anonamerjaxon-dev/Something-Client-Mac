import AppKit
import Foundation
import Polymorph

let args = CommandLine.arguments

func runDebug(skinPath: String) throws {
    let url = URL(fileURLWithPath: NSString(string: skinPath).expandingTildeInPath)
    let theme = try CursorTheme.load(directory: url)
    for line in try Polymorph.runDiagnostics(theme: theme) {
        print(line)
        FileHandle.standardOutput.synchronizeFile()
    }
}

guard args.count >= 2 else {
    print("Usage:")
    print("  PolymorphCLI apply <skin-folder>    replace cursors with skin")
    print("  PolymorphCLI restore                back to system cursors")
    print("  PolymorphCLI capture                save current cursors as the stock set")
    print("  PolymorphCLI debug <skin-folder>    apply + registry dump + live seed monitor")
    exit(2)
}

switch args[1] {
case "apply":
    guard args.count == 3 else {
        print("apply requires a skin folder path")
        exit(2)
    }
    let url = URL(fileURLWithPath: NSString(string: args[2]).expandingTildeInPath)
    do {
        let theme = try CursorTheme.load(directory: url)
        let report = try Polymorph.apply(theme: theme)
        print(report.summary)
        for failure in report.failures {
            print("  failed \(failure.cgsName): \(failure.error!)")
        }
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
case "capture":
    do {
        let count = try Polymorph.captureStockCursors()
        print("Captured \(count) stock cursor(s) to \(Polymorph.stockCaptureDirectory.path)")
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
case "restore":
    do {
        if Polymorph.hasStockCapture() {
            let count = try Polymorph.restoreFromStockCapture()
            print("Re-registered \(count) stock cursor(s) from capture")
        } else {
            try Polymorph.restore()
            print("System cursors restored (unregister-only; no capture existed)")
        }
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
case "debug":
    guard args.count == 3 else {
        print("debug requires a skin folder path")
        exit(2)
    }
    do {
        try runDebug(skinPath: args[2])
    } catch {
        print("ERROR: \(error)")
        exit(1)
    }
default:
    print("Unknown command: \(args[1])")
    exit(2)
}
