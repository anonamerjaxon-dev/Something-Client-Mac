import Foundation
import CoreVideo
import AppKit
import QuartzCore

public final class GhostTrail {
    public static var current: GhostTrail?

    private var configuration: GhostTrailConfiguration
    private var trailWindow: GhostTrailWindow?
    private var windowTracker: WindowTracker?
    private var isRunning: Bool = false
    private var displayLink: AnyObject?
    private var displayLinkTarget: DisplayLinkTarget?
    private var displayLinkUserInfo: UnsafeMutableRawPointer?

    deinit {
        GhostTrail.current = nil
        stopDisplayLink()
    }

    // MARK: - Builder

    public init() {
        self.configuration = GhostTrailConfiguration()
    }

    @discardableResult
    public func strokeColor(_ color: TrailColor) -> GhostTrail {
        configuration.strokeColor = color
        return self
    }

    @discardableResult
    public func strokeWidth(_ width: CGFloat) -> GhostTrail {
        configuration.strokeWidth = max(width, 0.5)
        return self
    }

    @discardableResult
    public func frameCount(_ count: Int) -> GhostTrail {
        configuration.frameCount = max(count, 10)
        return self
    }

    @discardableResult
    public func fadeDuration(_ duration: TimeInterval) -> GhostTrail {
        configuration.fadeDuration = max(duration, 0.1)
        return self
    }

    @discardableResult
    public func movementThreshold(_ threshold: CGFloat) -> GhostTrail {
        configuration.movementThreshold = max(threshold, 1)
        return self
    }

    @discardableResult
    public func opacity(_ value: Double) -> GhostTrail {
        configuration.opacity = max(min(value, 1.0), 0.0)
        return self
    }

    @discardableResult
    public func style(_ style: TrailStyle) -> GhostTrail {
        configuration.style = style
        return self
    }

    @discardableResult
    public func glow(_ config: GlowConfig) -> GhostTrail {
        configuration.glow = config
        return self
    }

    @discardableResult
    public func preset(_ config: GhostTrailConfiguration) -> GhostTrail {
        self.configuration = config
        return self
    }

    // MARK: - Lifecycle

    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return false }

        print("[GhostTrail] start() called")

        let tracker = WindowTracker(
            frameCount: configuration.frameCount,
            fadeDuration: configuration.fadeDuration
        )
        windowTracker = tracker

        let window = GhostTrailWindow(configuration: configuration)
        trailWindow = window
        window.orderFrontRegardless()

        startDisplayLink()

        isRunning = true
        let previous = GhostTrail.current
        GhostTrail.current = nil
        previous?.stop()
        GhostTrail.current = self
        return true
    }

    public func stop() {
        guard isRunning else { return }

        stopDisplayLink()
        trailWindow?.orderOut(nil as Any?)
        trailWindow = nil
        windowTracker?.clearAll()
        windowTracker = nil
        isRunning = false
        if GhostTrail.current === self {
            GhostTrail.current = nil
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()
        print("[GhostTrail] startDisplayLink() called")

        if #available(macOS 15.0, *) {
            let target = DisplayLinkTarget(ghostTrail: self)
            displayLinkTarget = target
            guard let screen = NSScreen.main else {
                print("[GhostTrail] ERROR: no main screen")
                return
            }
            let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.fire))
            link.add(to: .main, forMode: .common)
            displayLink = link
            print("[GhostTrail] Display link started (macOS 15+ CADisplayLink path)")
        } else {
            print("[GhostTrail] Starting legacy CVDisplayLink")
            startLegacyDisplayLink()
        }
    }

    @available(macOS, deprecated: 15.0, message: "CVDisplayLink used for macOS 13-14 compatibility")
    private func startLegacyDisplayLink() {
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnError }
            let trail = Unmanaged<GhostTrail>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { [weak trail] in
                trail?.updateTrail()
            }
            return kCVReturnSuccess
        }

        var cvLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&cvLink)
        guard let link = cvLink else { return }

        let unmanaged = Unmanaged.passRetained(self)
        displayLinkUserInfo = unmanaged.toOpaque()
        CVDisplayLinkSetOutputCallback(link, callback, displayLinkUserInfo)
        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        if #available(macOS 15.0, *) {
            (displayLink as? CADisplayLink)?.invalidate()
            displayLink = nil
            displayLinkTarget = nil
        } else {
            stopLegacyDisplayLink()
        }
    }

    @available(macOS, deprecated: 15.0, message: "CVDisplayLink used for macOS 13-14 compatibility")
    private func stopLegacyDisplayLink() {
        let link = displayLink as! CVDisplayLink
        CVDisplayLinkStop(link)
        displayLink = nil
        if let opaque = displayLinkUserInfo {
            Unmanaged<GhostTrail>.fromOpaque(opaque).release()
            displayLinkUserInfo = nil
        }
    }

    // MARK: - Trail Update

    fileprivate func updateTrail() {
        guard isRunning, let tracker = windowTracker else { return }

        let trails = tracker.poll()
        trailWindow?.update(trails: trails)
    }
}

// MARK: - DisplayLink Target (macOS 15+)

private final class DisplayLinkTarget: NSObject {
    private weak var ghostTrail: GhostTrail?

    init(ghostTrail: GhostTrail) {
        self.ghostTrail = ghostTrail
        super.init()
    }

    @objc func fire() {
        ghostTrail?.updateTrail()
    }
}