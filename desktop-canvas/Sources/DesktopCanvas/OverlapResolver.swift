import Foundation
import CoreGraphics

public enum OverlapResolver {

    public static func detectOverlaps(in canvases: [CanvasModel]) -> [(UUID, UUID)] {
        var overlaps: [(UUID, UUID)] = []
        for i in 0..<canvases.count {
            for j in (i + 1)..<canvases.count {
                if canvases[i].frame.intersects(canvases[j].frame) {
                    overlaps.append((canvases[i].id, canvases[j].id))
                }
            }
        }
        return overlaps
    }

    public static func resolve(
        moving: CanvasModel,
        against others: [CanvasModel],
        preferredDirection: CGVector = .zero
    ) -> CGRect {
        var resolved = moving.frame
        let others = others.filter { $0.id != moving.id }

        for other in others {
            guard resolved.intersects(other.frame) else { continue }

            let pushRight = other.frame.maxX - resolved.minX + 1
            let pushLeft = resolved.maxX - other.frame.minX + 1
            let pushUp = other.frame.maxY - resolved.minY + 1
            let pushDown = resolved.maxY - other.frame.minY + 1

            var pushes: [(CGFloat, CGVector)] = [
                (pushRight, CGVector(dx: 1, dy: 0)),
                (pushLeft, CGVector(dx: -1, dy: 0)),
                (pushUp, CGVector(dx: 0, dy: 1)),
                (pushDown, CGVector(dx: 0, dy: -1)),
            ]

            pushes.sort { a, b in
                let aDot = a.1.dx * preferredDirection.dx + a.1.dy * preferredDirection.dy
                let bDot = b.1.dx * preferredDirection.dx + b.1.dy * preferredDirection.dy
                if aDot != bDot { return aDot > bDot }
                return a.0 < b.0
            }

            resolved.origin.x += pushes[0].1.dx * pushes[0].0
            resolved.origin.y += pushes[0].1.dy * pushes[0].0
        }

        return resolved
    }

    public enum ValidationError: Error, LocalizedError {
        case overlappingCanvases([(UUID, UUID)])

        public var errorDescription: String? {
            switch self {
            case .overlappingCanvases(let pairs):
                return "Layout contains \(pairs.count) overlapping canvas pair(s)"
            }
        }
    }

    public static func validate(_ canvases: [CanvasModel]) throws {
        let overlaps = detectOverlaps(in: canvases)
        if !overlaps.isEmpty {
            throw ValidationError.overlappingCanvases(overlaps)
        }
    }
}