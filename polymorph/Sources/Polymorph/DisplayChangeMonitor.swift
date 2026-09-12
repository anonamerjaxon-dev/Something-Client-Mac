import CoreGraphics
import Foundation

private let beginConfigurationBit: UInt32 = 1 << 0

private func polymorphDisplayReconfiguration(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let monitor = Unmanaged<DisplayChangeMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let isBeginPass = flags.rawValue & beginConfigurationBit != 0 || flags.rawValue == 0
    if !isBeginPass {
        DispatchQueue.main.async {
            monitor.handler()
        }
    }
}

public final class DisplayChangeMonitor {
    var registered = false
    let handler: () -> Void

    public init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() {
        guard !registered else { return }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        let result = CGDisplayRegisterReconfigurationCallback(polymorphDisplayReconfiguration, opaque)
        registered = (result == .success)
    }

    public func stop() {
        guard registered else { return }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(polymorphDisplayReconfiguration, opaque)
        registered = false
    }
}
