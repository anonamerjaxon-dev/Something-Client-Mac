import Foundation
import QuartzCore
import AppKit

/// Main entry point for the CursorTrail library.
///
/// ## Usage
///
/// ```swift
/// import CursorTrail
///
/// CursorTrail()
///     .color(.gradient(.red, .blue))
///     .thickness(12)
///     .style(.ribbon)
///     .start()
///
/// CursorTrail.current?.stop()
/// ```
public final class CursorTrail {
    public static var current: CursorTrail?

    private var configuration: TrailConfiguration
    private var trailWindow: TrailWindow?
    private var trailPoints: RingBuffer<TrailPoint>
    private var lastMouseLocation: CGPoint = .zero
    private var lastTimestamp: CFTimeInterval = 0
    private var isRunning: Bool = false
    private var updateTimer: Timer?
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
        self.trailPoints = RingBuffer(capacity: configuration.length)
        return self
    }

    @discardableResult
    public func fadeSpeed(_ speed: Double) -> CursorTrail {
        configuration.fadeSpeed = max(speed, 0.1)
        return self
    }

    @discardableResult
    public func rainbowSpeed(_ speed: Double) -> CursorTrail {
        configuration.rainbowSpeed = speed
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
    public func speed(_ mode: SpeedMode) -> CursorTrail {
        configuration.speedMode = mode
        return self
    }

    @discardableResult
    public func glow(_ config: GlowConfig) -> CursorTrail {
        configuration.glow = config
        return self
    }

    @discardableResult
    public func particles(_ config: ParticleConfig) -> CursorTrail {
        configuration.particles = config
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

        let window = TrailWindow(configuration: configuration)
        self.trailWindow = window
        window.orderFrontRegardless()

        startUpdateTimer()

        isRunning = true
        CursorTrail.current = self
        return true
    }

    public func stop() {
        guard isRunning else { return }

        stopUpdateTimer()
        trailWindow?.orderOut(nil)
        trailWindow = nil
        trailPoints.clear()
        isRunning = false
        CursorTrail.current = nil
    }

    // MARK: - Update Timer (60fps)

    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateTrail()
        }
        if let timer = updateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateTrail() {
        guard isRunning else { return }

        var currentLocation = NSEvent.mouseLocation
        currentLocation.y = screenHeight - currentLocation.y

        let dx = currentLocation.x - lastMouseLocation.x
        let dy = currentLocation.y - lastMouseLocation.y
        let distSq = dx * dx + dy * dy
        let threshold: CGFloat = 0.5
        let isMoving = distSq > threshold * threshold

        if isMoving {
            let currentTime = CACurrentMediaTime()
            let dt = currentTime - lastTimestamp
            let distance = sqrt(distSq)
            let velocity = dt > 0 ? CGFloat(distance / dt) : 0

            let point = TrailPoint(position: currentLocation, timestamp: currentTime, velocity: velocity)
            trailPoints.append(point)
            lastMouseLocation = currentLocation
            lastTimestamp = currentTime
        }

        if isMoving {
            fadeAccumulator = 0
        } else if trailPoints.count > 0 {
            fadeAccumulator += configuration.fadeSpeed
            while fadeAccumulator >= 1.0 && trailPoints.count > 0 {
                _ = trailPoints.removeFirst()
                fadeAccumulator -= 1.0
            }
            fadeAccumulator = min(fadeAccumulator, 10.0)
        }

        if isMoving || trailPoints.count > 0 {
            trailWindow?.update(trailPoints)
        }
    }
}
