import AppKit
import CoreGraphics
import Foundation

public struct ApplyReport {
    public struct Entry {
        public let state: CursorState
        public let cgsName: String
        public let error: Error?
    }

    public let entries: [Entry]

    public var isSuccess: Bool {
        entries.allSatisfy { $0.error == nil }
    }

    public var failures: [Entry] {
        entries.filter { $0.error != nil }
    }

    public var summary: String {
        if isSuccess {
            return "Applied \(entries.count) cursor(s) successfully"
        }
        return "\(entries.count - failures.count)/\(entries.count) applied; \(failures.count) failed: "
            + failures.map { "\($0.state.rawValue) (\($0.error!.localizedDescription))" }.joined(separator: ", ")
    }
}

public enum PolymorphError: Error, CustomStringConvertible {
    case bridgeUnavailable
    case restoreFailed(CGError)
    case noStockCapture

    public var description: String {
        switch self {
        case .bridgeUnavailable:
            return "CGS private cursor API unavailable on this macOS version"
        case .restoreFailed(let code):
            return "Restore failed with CGError \(code)"
        case .noStockCapture:
            return "No stock capture found — run PolymorphCLI capture on a clean session (or reboot) first"
        }
    }
}

public enum Polymorph {
    public static let displayNames = ["com.apple.coregraphics.ArrowS", "com.apple.coregraphics.Arrow"]

    public static var diagnosticLogger: ((String) -> Void)?

    public static func apply(theme: CursorTheme, refresh: Bool = true) throws -> ApplyReport {
        guard CGSBridge.isAvailable() else {
            throw PolymorphError.bridgeUnavailable
        }
        return try apply(theme: theme, cid: CGSBridge.shared.mainConnectionID(), refresh: refresh)
    }

    public static func apply(theme: CursorTheme, cid: Int32, refresh: Bool = true) throws -> ApplyReport {
        guard CGSBridge.isAvailable() else {
            throw PolymorphError.bridgeUnavailable
        }
        let bridge = CGSBridge.shared

        _ = bridge.unregisterAll(cid)
        if cid == bridge.mainConnectionID(), hasStockCapture() {
            _ = registerStockSet(bridge: bridge, cid: cid, instantly: false, activate: false)
        }

        var entries: [ApplyReport.Entry] = []
        for cursor in theme.cursors {
            entries.append(contentsOf: try register(cursor: cursor, cid: cid, bridge: bridge))
        }

        if cid == bridge.mainConnectionID() {
            show(arrow: true)
            if refresh {
                finalizeRefresh()
            }
        }

        return ApplyReport(entries: entries)
    }

    public static func connectionID(forWindowNumber windowNumber: UInt32) -> Int32? {
        guard CGSBridge.isAvailable(), let getWindowOwner = CGSBridge.shared.getWindowOwner else { return nil }
        var owner: Int32 = 0
        let err = getWindowOwner(CGSBridge.shared.mainConnectionID(), windowNumber, &owner)
        guard err == .success, owner != 0 else { return nil }
        return owner
    }

    public static func show(arrow: Bool = true) {
        guard CGSBridge.isAvailable() else { return }
        showCursorNamed(displayNames, bridge: CGSBridge.shared, cid: CGSBridge.shared.mainConnectionID())
    }

    private static func showCursorNamed(_ names: [String], bridge: CGSBridge, cid: Int32) {
        for name in names {
            var seed: Int32 = 0
            let err = name.withCString { cName in
                bridge.setRegisteredCursor(cid, cName, &seed)
            }
            if err == .success {
                return
            }
        }
    }

    private static func register(cursor: ResolvedCursor, cid: Int32, bridge: CGSBridge) throws -> [ApplyReport.Entry] {
        let images = try ThemeImageLoader.cgImages(
            oneXURL: cursor.imageFile,
            retinaURL: cursor.retinaFile,
            pointSize: cursor.pointSize
        )
        var seed: Int32 = 0
        return cursor.state.cgsNames.map { name in
            let err = name.withCString { cName in
                bridge.registerCursorWithImages(
                    cid,
                    cName,
                    true,
                    true,
                    cursor.pointSize,
                    cursor.hotspot,
                    1,
                    0,
                    images as CFArray,
                    &seed
                )
            }
            guard err == .success else {
                return ApplyReport.Entry(state: cursor.state, cgsName: name, error: PolymorphRegistrationError(code: err))
            }
            var activateSeed: Int32 = 0
            _ = name.withCString { cName in
                bridge.setRegisteredCursor(cid, cName, &activateSeed)
            }
            if name.hasPrefix("com.apple.cursor.") {
                let indexString = name.dropFirst("com.apple.cursor.".count)
                if let slot = Int32(indexString) {
                    _ = bridge.setCoreCursor(cid, slot)
                }
            }
            return ApplyReport.Entry(state: cursor.state, cgsName: name, error: nil)
        }
    }

    public static let maxCoreCursorSlot = 43

    public static func restore() throws {
        guard CGSBridge.isAvailable() else {
            throw PolymorphError.bridgeUnavailable
        }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        let err = bridge.unregisterAll(cid)
        guard err == .success else {
            throw PolymorphError.restoreFailed(err)
        }
        for slot in 0...maxCoreCursorSlot {
            _ = bridge.setCoreCursor(cid, Int32(slot))
        }
        if hasStockCapture() {
            _ = registerStockSet(bridge: bridge, cid: cid, instantly: true, activate: true)
        }
        finalizeRefresh()
    }

    public static func nudgeCursorScale(bump: CGFloat = 0.3) throws {
        guard CGSBridge.isAvailable() else {
            throw PolymorphError.bridgeUnavailable
        }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        var scale: CGFloat = 1.0
        _ = bridge.getCursorScale(cid, &scale)
        _ = bridge.setCursorScale(cid, scale + bump)
        _ = bridge.setCursorScale(cid, scale)
    }

    public static func scaleProbe() {
        guard CGSBridge.isAvailable() else { return }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        var scale: CGFloat = 1.0
        let getErr = bridge.getCursorScale(cid, &scale)
        diagnosticLogger?("probe: get err=\(getErr.rawValue) scale=\(scale)")
        let original = (getErr == .success && scale.isFinite && scale > 0) ? scale : 1.0
        let e1 = bridge.setCursorScale(cid, 2.0)
        diagnosticLogger?("probe: set 2.0 err=\(e1.rawValue)")
        usleep(120_000)
        var verify: CGFloat = -1
        let vErr = bridge.getCursorScale(cid, &verify)
        diagnosticLogger?("probe: verify err=\(vErr.rawValue) scale=\(verify)")
        let e2 = bridge.setCursorScale(cid, original)
        diagnosticLogger?("probe: restore \(original) err=\(e2.rawValue)")
    }

    public static func finalizeRefresh(scaleBump: CGFloat = 0.1) {
        guard CGSBridge.isAvailable() else { return }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        bridge.setDockCursorOverride(cid, true)
        diagnosticLogger?("finalize: dockOverride called (void ABI)")
        var scale: CGFloat = 1.0
        if bridge.getCursorScale(cid, &scale) == .success, scale.isFinite, scale > 0 {
            let e1 = bridge.setCursorScale(cid, scale + scaleBump)
            let e2 = bridge.setCursorScale(cid, scale)
            diagnosticLogger?("finalize: scale get=\(scale) set errs=\(e1.rawValue),\(e2.rawValue)")
        } else {
            let e1 = bridge.setCursorScale(cid, 1.0 + scaleBump)
            let e2 = bridge.setCursorScale(cid, 1.0)
            diagnosticLogger?("finalize: scale get FAILED, blind set errs=\(e1.rawValue),\(e2.rawValue)")
        }
        let sysErr = bridge.setSystemDefinedCursor(cid, 0)
        diagnosticLogger?("finalize: setSystemDefinedCursor(0) err=\(sysErr.rawValue)")
    }

    public static func reassert() {
        guard CGSBridge.isAvailable() else { return }
        let bridge = CGSBridge.shared
        let cid = bridge.mainConnectionID()
        show(arrow: true)
        bridge.setDockCursorOverride(cid, true)
        _ = bridge.setSystemDefinedCursor(cid, 0)
    }

    private static var enforcementTimer: Timer?
    private static var enforcedTheme: CursorTheme?
    private static var enforcementCount = 0
    private static var enforcedRegistrations: [(names: [String], pointSize: CGSize, hotspot: CGPoint, images: [CGImage])] = []

    public static func startEnforcement(theme: CursorTheme, interval: TimeInterval = 1.5) {
        stopEnforcement()
        enforcedTheme = theme
        enforcedRegistrations = theme.cursors.compactMap { cursor in
            guard let images = try? ThemeImageLoader.cgImages(
                oneXURL: cursor.imageFile,
                retinaURL: cursor.retinaFile,
                pointSize: cursor.pointSize
            ) else { return nil }
            return (cursor.state.cgsNames, cursor.pointSize, cursor.hotspot, images)
        }
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            guard enforcedTheme != nil else { return }
            enforcementCount += 1
            guard CGSBridge.isAvailable() else { return }
            let bridge = CGSBridge.shared
            let cid = bridge.mainConnectionID()
            for registration in enforcedRegistrations {
                for name in registration.names {
                    var seed: Int32 = 0
                    _ = name.withCString { cName in
                        bridge.registerCursorWithImages(
                            cid, cName, true, true,
                            registration.pointSize, registration.hotspot,
                            1, 0, registration.images as CFArray, &seed
                        )
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        enforcementTimer = timer
    }

    public static func stopEnforcement() {
        enforcementTimer?.invalidate()
        enforcementTimer = nil
        enforcedTheme = nil
        enforcementCount = 0
    }

    public static func isEnforcing() -> Bool {
        enforcementTimer != nil
    }

    public static var enforcementReapplies: Int {
        enforcementCount
    }
}

public struct PolymorphRegistrationError: Error, CustomStringConvertible {
    public let code: CGError

    public var description: String {
        "CGError \(code.rawValue)"
    }
}
