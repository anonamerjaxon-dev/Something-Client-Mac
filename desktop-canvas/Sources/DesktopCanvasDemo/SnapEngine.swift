import Foundation
import CoreGraphics
import DesktopCanvas

struct SnapEngine {
    var gridSize: CGFloat
    var snapToScreenEdges: Bool
    var snapToCanvasEdges: Bool
    var snapToGrid: Bool
    var screenFrame: CGRect
    var otherCanvases: [(id: UUID, frame: CGRect)]
    var margin: CGFloat
    var snapThreshold: CGFloat = 6

    func snap(_ rect: CGRect) -> CGRect {
        var result = rect
        result.origin = snapPoint(result.origin, excluding: nil)
        return result
    }

    func snapOrigin(_ origin: CGPoint, for size: CGSize) -> CGPoint {
        snapPoint(origin, excluding: nil)
    }

    func snapRect(_ rect: CGRect, excluding excludedID: UUID? = nil) -> CGRect {
        var result = rect
        result.origin = snapEdgePoint(rect, excluding: excludedID)
        return result
    }

    func snapSize(_ size: CGSize, for canvas: CanvasModel) -> CGSize {
        if canvas.type == .gameOfLife, let config = canvas.gameOfLifeConfig {
            let cellSize = CGFloat(config.cellSize)
            let snappedW = round(size.width / cellSize) * cellSize
            let snappedH = round(size.height / cellSize) * cellSize
            return CGSize(
                width: max(snappedW, 10 * cellSize),
                height: max(snappedH, 10 * cellSize)
            )
        }
        return size
    }

    func snapResizeSize(_ size: CGSize, canvasID: UUID, canvas: CanvasModel) -> CGSize {
        var result = snapSize(size, for: canvas)

        if snapToCanvasEdges {
            for other in otherCanvases where other.id != canvasID {
                let ow = other.frame.width
                let oh = other.frame.height
                if abs(result.width - ow) < snapThreshold {
                    result.width = ow
                }
                if abs(result.height - oh) < snapThreshold {
                    result.height = oh
                }
            }
        }

        return result
    }

    private func snapEdgePoint(_ rect: CGRect, excluding excludedID: UUID?) -> CGPoint {
        var bestX = rect.origin.x
        var bestY = rect.origin.y
        var bestXDistance = snapThreshold
        var bestYDistance = snapThreshold

        let candidateTargets = candidateSnapTargets(excluding: excludedID)

        for target in candidateTargets {
            let leftDist = abs(rect.minX - target)
            if leftDist < bestXDistance {
                bestX = target
                bestXDistance = leftDist
            }
            let rightDist = abs(rect.maxX - target)
            if rightDist < bestXDistance {
                bestX = target - rect.width
                bestXDistance = rightDist
            }
            let topDist = abs(rect.minY - target)
            if topDist < bestYDistance {
                bestY = target
                bestYDistance = topDist
            }
            let bottomDist = abs(rect.maxY - target)
            if bottomDist < bestYDistance {
                bestY = target - rect.height
                bestYDistance = bottomDist
            }
        }

        return CGPoint(x: bestX, y: bestY)
    }

    private func candidateSnapTargets(excluding excludedID: UUID?) -> [CGFloat] {
        var targets: [CGFloat] = []

        if snapToScreenEdges {
            targets.append(screenFrame.minX)
            targets.append(screenFrame.maxX)
            targets.append(screenFrame.minY)
            targets.append(screenFrame.maxY)
            targets.append(screenFrame.midX)
            targets.append(screenFrame.midY)
        }

        if snapToCanvasEdges {
            for other in otherCanvases where other.id != excludedID {
                let f = other.frame
                targets.append(f.minX)
                targets.append(f.maxX)
                targets.append(f.minY)
                targets.append(f.maxY)
            }
        }

        if snapToGrid {
            targets.append(contentsOf: [])
        }

        return targets
    }

    private func snapPoint(_ point: CGPoint, excluding excludedID: UUID?) -> CGPoint {
        var best = point
        var bestDistance = snapThreshold

        if snapToScreenEdges {
            checkSnap(&best, &bestDistance, point, screenFrame.minX, axis: .x)
            checkSnap(&best, &bestDistance, point, screenFrame.maxX, axis: .x)
            checkSnap(&best, &bestDistance, point, screenFrame.minY, axis: .y)
            checkSnap(&best, &bestDistance, point, screenFrame.maxY, axis: .y)
            checkSnap(&best, &bestDistance, point, screenFrame.midX, axis: .x)
            checkSnap(&best, &bestDistance, point, screenFrame.midY, axis: .y)
        }

        if snapToCanvasEdges {
            for other in otherCanvases where other.id != excludedID {
                let f = other.frame
                checkSnap(&best, &bestDistance, point, f.minX - margin, axis: .x)
                checkSnap(&best, &bestDistance, point, f.maxX + margin, axis: .x)
                checkSnap(&best, &bestDistance, point, f.minY - margin, axis: .y)
                checkSnap(&best, &bestDistance, point, f.maxY + margin, axis: .y)
            }
        }

        if snapToGrid {
            let snappedX = round(point.x / gridSize) * gridSize
            let snappedY = round(point.y / gridSize) * gridSize
            let dx = abs(point.x - snappedX)
            let dy = abs(point.y - snappedY)
            if dx < bestDistance {
                best.x = snappedX
                bestDistance = dx
            }
            if dy < bestDistance {
                best.y = snappedY
                bestDistance = dy
            }
        }

        return best
    }

    private enum Axis { case x, y }

    private func checkSnap(_ best: inout CGPoint, _ bestDist: inout CGFloat,
                           _ point: CGPoint, _ target: CGFloat, axis: Axis) {
        let distance: CGFloat
        switch axis {
        case .x: distance = abs(point.x - target)
        case .y: distance = abs(point.y - target)
        }
        guard distance < bestDist else { return }
        switch axis {
        case .x: best.x = target
        case .y: best.y = target
        }
        bestDist = distance
    }

    func snapCornerResize(
        rect: CGRect,
        handle: ResizeHandle,
        target: CGPoint,
        canvas: CanvasModel
    ) -> CGRect {
        var result = rect

        if canvas.type == .video, let naturalSize = canvas.videoConfig?.naturalSize,
           naturalSize.width > 0, naturalSize.height > 0 {
            result = aspectSnapCornerResize(rect: rect, handle: handle, target: target, aspectRatio: naturalSize.width / naturalSize.height)
        } else {
            let cellSize: CGFloat = canvas.type == .gameOfLife
                ? CGFloat(canvas.gameOfLifeConfig?.cellSize ?? 8)
                : 1

            var snappedTarget = target
            if snapToGrid {
                snappedTarget.x = round(target.x / gridSize) * gridSize
                snappedTarget.y = round(target.y / gridSize) * gridSize
            }

            switch handle {
            case .topLeft:
                let newMinX = min(snappedTarget.x, result.maxX - 10 * cellSize)
                let newMinY = min(snappedTarget.y, result.maxY - 10 * cellSize)
                result = CGRect(
                    x: newMinX, y: newMinY,
                    width: result.maxX - newMinX, height: result.maxY - newMinY
                )
            case .topRight:
                let newMaxX = max(snappedTarget.x, result.minX + 10 * cellSize)
                let newMinY = min(snappedTarget.y, result.maxY - 10 * cellSize)
                result = CGRect(
                    x: result.minX, y: newMinY,
                    width: newMaxX - result.minX, height: result.maxY - newMinY
                )
            case .bottomLeft:
                let newMinX = min(snappedTarget.x, result.maxX - 10 * cellSize)
                let newMaxY = max(snappedTarget.y, result.minY + 10 * cellSize)
                result = CGRect(
                    x: newMinX, y: result.minY,
                    width: result.maxX - newMinX, height: newMaxY - result.minY
                )
            case .bottomRight:
                let newMaxX = max(snappedTarget.x, result.minX + 10 * cellSize)
                let newMaxY = max(snappedTarget.y, result.minY + 10 * cellSize)
                result = CGRect(
                    x: result.minX, y: result.minY,
                    width: newMaxX - result.minX, height: newMaxY - result.minY
                )
            case .top, .bottom, .left, .right:
                break
            }
        }

        if canvas.type == .gameOfLife {
            let newSize = snapResizeSize(result.size, canvasID: canvas.id, canvas: canvas)
            result.size.width = newSize.width
            result.size.height = newSize.height
        }

        return result
    }

    private func aspectSnapCornerResize(
        rect: CGRect,
        handle: ResizeHandle,
        target: CGPoint,
        aspectRatio: CGFloat
    ) -> CGRect {
        var result = rect
        let minSize: CGFloat = 50

        switch handle {
        case .bottomRight:
            let newW = max(target.x - rect.minX, minSize)
            let newH = newW / aspectRatio
            result.size = CGSize(width: newW, height: newH)

        case .bottomLeft:
            let newW = max(rect.maxX - target.x, minSize)
            let newH = newW / aspectRatio
            result = CGRect(
                x: rect.maxX - newW,
                y: rect.minY,
                width: newW,
                height: newH
            )

        case .topRight:
            let newW = max(target.x - rect.minX, minSize)
            let newH = newW / aspectRatio
            result = CGRect(
                x: rect.minX,
                y: rect.maxY - newH,
                width: newW,
                height: newH
            )

        case .topLeft:
            let newW = max(rect.maxX - target.x, minSize)
            let newH = newW / aspectRatio
            result = CGRect(
                x: rect.maxX - newW,
                y: rect.maxY - newH,
                width: newW,
                height: newH
            )

        default:
            break
        }

        return result
    }
}

enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

    static let corners: [ResizeHandle] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    static let edges: [ResizeHandle] = [.top, .left, .right, .bottom]
}

extension ResizeHandle {
    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .top:         return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .left:        return CGPoint(x: rect.minX, y: rect.midY)
        case .right:       return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottom:      return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}