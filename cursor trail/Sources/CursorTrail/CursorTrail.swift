import Foundation
import QuartzCore
import AppKit
import CoreVideo

public final class CursorTrail {
    public static var current: CursorTrail?

    private var configuration: TrailConfiguration
    private var trailWindow: TrailWindow?
    private var trailPoints: RingBuffer<TrailPoint>
    private var lastMouseLocation: CGPoint = .zero
    private var isRunning: Bool = false
    private var displayLink: CVDisplayLink?
    private var displayLinkUserInfo: UnsafeMutableRawPointer?
    private var fadeAccumulator: Double = 0
    private var screenHeight: CGFloat = 0

    deinit {
        stop()
    }

    // MARK: - Builder

    public init() {
        self.configuration = TrailConfiguration()
        self.trailPoints = RingBuffer(capacity: configuration.length)
    }

    @discardableResult
    public func color(_ color: TrailColor) -> CursorTrail {
        configuration.color = color
        return self
    }

    @discardableResult
    public func thickness(_ thickness: CGFloat) -> CursorTrail {
        configuration.thickness = max(thickness, 1)
        return self
    }

    @discardableResult
    public func length(_ length: Int) -> CursorTrail {
        configuration.length = max(length, 10)
        trailPoints = RingBuffer(capacity: configuration.length)
        return self
    }

    @discardableResult
    public func fadeSpeed(_ speed: Double) -> CursorTrail {
        configuration.fadeSpeed = max(speed, 0.1)
        return self
    }

    @discardableResult
    public func rainbowSpeed(_ speed: Double) -> CursorTrail {
        configuration.rainbowSpeed = max(speed, 0.1)
        return self
    }

    @discardableResult
    public func diminishing(_ enabled: Bool) -> CursorTrail {
        configuration.diminishing = enabled
        return self
    }

    @discardableResult
    public func diminishingIntensity(_ intensity: Double) -> CursorTrail {
        configuration.diminishingIntensity = max(min(intensity, 1.0), 0.0)
        return self
    }

    @discardableResult
    public func style(_ style: TrailStyle) -> CursorTrail {
        configuration.style = style
        return self
    }

    @discardableResult
    public func glow(_ config: GlowConfig) -> CursorTrail {
        configuration.glow = config
        return self
    }

    @discardableResult
    public func opacity(_ value: Double) -> CursorTrail {
        configuration.opacity = max(min(value, 1.0), 0.0)
        return self
    }

    // MARK: - Lifecycle

    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return false }

        screenHeight = NSScreen.main?.frame.height ?? 0
        lastMouseLocation = NSEvent.mouseLocation
        lastMouseLocation.y = screenHeight - lastMouseLocation.y

        let window = TrailWindow(configuration: configuration)
        trailWindow = window
        window.orderFrontRegardless()

        startDisplayLink()

        isRunning = true
        CursorTrail.current = self
        return true
    }

    public func stop() {
        guard isRunning else { return }

        stopDisplayLink()
        trailWindow?.orderOut(nil)
        trailWindow = nil
        trailPoints.clear()
        isRunning = false
        CursorTrail.current = nil
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnError }
            let trail = Unmanaged<CursorTrail>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { [weak trail] in
                trail?.updateTrail()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        let unmanaged = Unmanaged.passRetained(self)
        displayLinkUserInfo = unmanaged.toOpaque()
        CVDisplayLinkSetOutputCallback(link, callback, displayLinkUserInfo)
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
        if let opaque = displayLinkUserInfo {
            Unmanaged<CursorTrail>.fromOpaque(opaque).release()
            displayLinkUserInfo = nil
        }
    }

    // MARK: - Trail Update

    private static let movementThreshold: CGFloat = 0.5
    private static let maxFadeAccumulator: Double = 10.0

    private func updateTrail() {
        guard isRunning else { return }

        var location = NSEvent.mouseLocation
        location.y = screenHeight - location.y

        let dx = location.x - lastMouseLocation.x
        let dy = location.y - lastMouseLocation.y
        let isMoving = (dx * dx + dy * dy) > (Self.movementThreshold * Self.movementThreshold)

        if isMoving {
            trailPoints.append(TrailPoint(position: location))
            lastMouseLocation = location
            fadeAccumulator = 0
        } else if !trailPoints.isEmpty {
            fadeAccumulator += configuration.fadeSpeed
            while fadeAccumulator >= 1.0, !trailPoints.isEmpty {
                trailPoints.removeFirst()
                fadeAccumulator -= 1.0
            }
            fadeAccumulator = min(fadeAccumulator, Self.maxFadeAccumulator)
        }

        if isMoving || !trailPoints.isEmpty {
            trailWindow?.update(trailPoints)
        }
    }
}