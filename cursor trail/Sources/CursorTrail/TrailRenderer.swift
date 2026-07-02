import SwiftUI
import AppKit

/// Renders the cursor trail onto a SwiftUI GraphicsContext.
public final class TrailRenderer {
    private let configuration: TrailConfiguration
    /// Offset the entire trail below the cursor tip
    private static let yOffset: CGFloat = 16

    public init(configuration: TrailConfiguration) {
        self.configuration = configuration
    }

    public func draw(context: GraphicsContext, points: RingBuffer<TrailPoint>) {
        guard !points.isEmpty else { return }
        let now = CACurrentMediaTime()
        let opacity = configuration.opacity

        if points.count >= 2 {
            switch configuration.style {
            case .line:
                drawLine(context: context, points: points, now: now, opacity: opacity)
            case .ribbon:
                drawRibbon(context: context, points: points, now: now, opacity: opacity)
            }

            if let glow = configuration.glow {
                drawGlow(context: context, points: points, glow: glow, now: now, opacity: opacity)
            }

            if let particles = configuration.particles {
                drawParticles(context: context, points: points, particles: particles, opacity: opacity)
            }
        }
    }

    // MARK: - Line Drawing

    private func drawLine(context: GraphicsContext, points: RingBuffer<TrailPoint>, now: CFTimeInterval, opacity: Double) {
        let count = points.count
        if count < 2 { return }

        let path = createPolylinePath(points: points)
        let baseColor = colorForTrail(index: count / 2, total: count, now: now)
        let baseThickness = thicknessForPoint(index: count / 2, total: count)

        let dimMin = configuration.diminishingMin(forLine: true)
        for i in 0..<4 {
            let t = CGFloat(i) / 3
            let width = max(baseThickness * (dimMin + t * (1.0 - dimMin)), 0.5)
            let passOpacity = (0.15 + t * 0.85) * opacity

            context.stroke(
                path,
                with: .color(baseColor.opacity(passOpacity)),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Ribbon Drawing

    private func drawRibbon(context: GraphicsContext, points: RingBuffer<TrailPoint>, now: CFTimeInterval, opacity: Double) {
        guard points.count >= 3 else {
            drawLine(context: context, points: points, now: now, opacity: opacity)
            return
        }

        let count = points.count
        let baseWidth = configuration.thickness * 2
        let dimMin = configuration.diminishingMin(forLine: false)

        let samplesPerSegment = 8
        let totalSamples = (count - 1) * samplesPerSegment + 1
        var smoothPoints: [CGPoint] = []
        for i in 0..<totalSamples {
            let t = CGFloat(i) / CGFloat(samplesPerSegment)
            let idx = Int(t)
            let frac = t - CGFloat(idx)
            let p0 = points[max(idx - 1, 0)].position
            let p1 = points[idx].position
            let p2 = points[min(idx + 1, count - 1)].position
            let p3 = points[min(idx + 2, count - 1)].position
            let pt = catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: frac)
            smoothPoints.append(CGPoint(x: pt.x, y: pt.y + Self.yOffset))
        }

        let smoothCount = smoothPoints.count
        var leftSide: [CGPoint] = []
        var rightSide: [CGPoint] = []

        for i in 0..<smoothCount {
            let t = CGFloat(i) / CGFloat(max(smoothCount - 1, 1))
            let halfWidth = (baseWidth / 2.0) * (dimMin + t * (1.0 - dimMin))

            let prev = smoothPoints[max(i - 1, 0)]
            let next = smoothPoints[min(i + 1, smoothCount - 1)]
            let dir = CGPoint(x: next.x - prev.x, y: next.y - prev.y)
            let len = sqrt(dir.x * dir.x + dir.y * dir.y)
            let normal = len > 0
                ? CGPoint(x: -dir.y / len, y: dir.x / len)
                : CGPoint(x: 0, y: 1)

            let pos = smoothPoints[i]
            leftSide.append(CGPoint(x: pos.x + normal.x * halfWidth, y: pos.y + normal.y * halfWidth))
            rightSide.append(CGPoint(x: pos.x - normal.x * halfWidth, y: pos.y - normal.y * halfWidth))
        }

        var path = Path()
        path.move(to: leftSide[0])
        for i in 1..<smoothCount {
            path.addLine(to: leftSide[i])
        }
        for i in (0..<smoothCount).reversed() {
            path.addLine(to: rightSide[i])
        }
        path.closeSubpath()

        let baseColor = colorForTrail(index: count / 2, total: count, now: now)
        context.fill(path, with: .color(baseColor.opacity(opacity)))
    }

    private func catmullRom(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
        let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Glow Effect

    private func drawGlow(context: GraphicsContext, points: RingBuffer<TrailPoint>, glow: GlowConfig, now: CFTimeInterval, opacity: Double) {
        let path = createPolylinePath(points: points)
        let trailColor = colorForTrail(index: 0, total: points.count, now: now)
        let glowColor = (glow.color ?? trailColor).opacity(glow.intensity * 0.3 * opacity)

        var blurContext = context
        blurContext.addFilter(.blur(radius: glow.radius))
        blurContext.stroke(
            path,
            with: .color(glowColor),
            style: StrokeStyle(lineWidth: configuration.thickness + glow.radius, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Particles

    private func drawParticles(context: GraphicsContext, points: RingBuffer<TrailPoint>, particles: ParticleConfig, opacity: Double) {
        let strideBy = max(1, points.count / particles.count)
        for i in Swift.stride(from: 0, to: points.count, by: strideBy) {
            let point = points[i]
            let rect = CGRect(
                x: point.position.x - particles.size / 2,
                y: point.position.y - particles.size / 2,
                width: particles.size,
                height: particles.size
            )
            context.fill(Path(ellipseIn: rect), with: .color(particles.color.opacity(0.7 * opacity)))
        }
    }

    // MARK: - Helpers

    private func createPolylinePath(points: RingBuffer<TrailPoint>) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.position.x, y: first.position.y + Self.yOffset))
        for i in 1..<points.count {
            let p = points[i].position
            path.addLine(to: CGPoint(x: p.x, y: p.y + Self.yOffset))
        }
        return path
    }

    private func colorForTrail(index: Int, total: Int, now: CFTimeInterval) -> Color {
        switch configuration.color {
        case .solid(let c):
            return c
        case .gradient(let c1, let c2):
            let t = Double(index) / Double(max(total - 1, 1))
            let ns1 = NSColor(c1)
            let ns2 = NSColor(c2)
            guard let rgb1 = ns1.usingColorSpace(.sRGB),
                  let rgb2 = ns2.usingColorSpace(.sRGB) else { return c1 }
            let r = lerp(Double(rgb1.redComponent), Double(rgb2.redComponent), t)
            let g = lerp(Double(rgb1.greenComponent), Double(rgb2.greenComponent), t)
            let b = lerp(Double(rgb1.blueComponent), Double(rgb2.blueComponent), t)
            return Color(red: r, green: g, blue: b)
        case .rainbow:
            let cycleDuration = 3.0 / configuration.rainbowSpeed
            let hue = now.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
            return Color(hue: hue, saturation: 1.0, brightness: 1.0)
        }
    }

    private func thicknessForPoint(index: Int, total: Int) -> CGFloat {
        let baseThickness = configuration.thickness
        let progress = CGFloat(index) / CGFloat(max(total - 1, 1))
        let factor = 1.0 - progress * 0.5
        return baseThickness * factor
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
