import SwiftUI
import DesktopCanvas

enum DrawTool: String, CaseIterable {
    case pencil
    case line
    case rectangle
    case eraser

    var iconName: String {
        switch self {
        case .pencil: return "pencil"
        case .line: return "scribble"
        case .rectangle: return "rectangle"
        case .eraser: return "eraser"
        }
    }

    var label: String {
        switch self {
        case .pencil: return "Pencil"
        case .line: return "Line"
        case .rectangle: return "Rect"
        case .eraser: return "Eraser"
        }
    }
}

struct Pattern: Identifiable {
    let id = UUID()
    let name: String
    let cells: [(row: Int, col: Int)]

    static let gliderUp = Pattern(name: "Glider \u{2191}", cells: [
        (0,1), (1,2), (2,0), (2,1), (2,2)
    ])
    static let gliderRight = Pattern(name: "Glider \u{2192}", cells: [
        (0,0), (1,0), (1,2), (2,0), (2,1)
    ])
    static let gliderDown = Pattern(name: "Glider \u{2193}", cells: [
        (0,0), (0,1), (0,2), (1,2), (2,1)
    ])
    static let gliderLeft = Pattern(name: "Glider \u{2190}", cells: [
        (0,1), (1,0), (1,2), (2,0), (2,1)
    ])
    static let blinkerH = Pattern(name: "Blinker \u{2014}", cells: [
        (0,0), (0,1), (0,2)
    ])
    static let blinkerV = Pattern(name: "Blinker |", cells: [
        (0,0), (1,0), (2,0)
    ])
    static let block = Pattern(name: "Block", cells: [
        (0,0), (0,1), (1,0), (1,1)
    ])
    static let beehive = Pattern(name: "Beehive", cells: [
        (0,1),(0,2),(1,0),(1,3),(2,1),(2,2)
    ])
    static let boat = Pattern(name: "Boat", cells: [
        (0,0),(0,1),(1,0),(1,2),(2,1)
    ])
    static let loaf = Pattern(name: "Loaf", cells: [
        (0,1),(0,2),(1,0),(1,3),(2,1),(2,3),(3,2)
    ])
    static let lwssUp = Pattern(name: "LWSS \u{2191}", cells: [
        (0,1),(0,4),(1,0),(2,0),(2,4),(3,0),(3,1),(3,2),(3,3)
    ])
    static let lwssRight = Pattern(name: "LWSS \u{2192}", cells: [
        (0,2),(0,3),(0,4),(1,0),(1,4),(2,4),(3,0),(3,3)
    ])
    static let lwssDown = Pattern(name: "LWSS \u{2193}", cells: [
        (0,0),(0,1),(0,2),(0,3),(1,0),(1,4),(2,4),(3,1),(3,4)
    ])
    static let lwssLeft = Pattern(name: "LWSS \u{2190}", cells: [
        (0,2),(1,0),(1,3),(2,0),(3,0),(3,1),(3,2),(3,3)
    ])
    static let pulsar = Pattern(name: "Pulsar", cells: [
        (0,2),(0,3),(0,4),(0,8),(0,9),(0,10),
        (2,0),(2,5),(2,7),(2,12),(3,0),(3,5),(3,7),(3,12),
        (4,0),(4,5),(4,7),(4,12),(5,2),(5,3),(5,4),(5,8),(5,9),(5,10),
        (7,2),(7,3),(7,4),(7,8),(7,9),(7,10),
        (8,0),(8,5),(8,7),(8,12),(9,0),(9,5),(9,7),(9,12),
        (10,0),(10,5),(10,7),(10,12),
        (12,2),(12,3),(12,4),(12,8),(12,9),(12,10)
    ])
    static let gosperGun = Pattern(name: "Gosper Gun", cells: [
        (0,24),(1,22),(1,24),(2,12),(2,13),(2,20),(2,21),(2,34),(2,35),
        (3,11),(3,15),(3,20),(3,21),(3,34),(3,35),(4,0),(4,1),(4,10),
        (4,16),(4,20),(4,21),(5,0),(5,1),(5,10),(5,14),(5,16),(5,17),
        (5,22),(5,24),(6,10),(6,16),(6,24),(7,11),(7,15),(8,12),(8,13)
    ])

    static let allPatterns: [Pattern] = [
        gliderUp, gliderRight, gliderDown, gliderLeft,
        blinkerH, blinkerV,
        block, beehive, boat, loaf,
        lwssUp, lwssRight, lwssDown, lwssLeft,
        pulsar, gosperGun
    ]
}

struct GridEditorView: View {
    let canvasID: UUID
    @ObservedObject var state: EditorState

    @State private var selectedTool: DrawTool = .pencil
    @State private var selectedPattern: Pattern?
    @State private var showGridLines = true
    @State private var density: Double = 0.5
    @State private var grid: [UInt8] = []
    @State private var gridW: Int = 0
    @State private var gridH: Int = 0
    @State private var cellSize: Int = 8
    @State private var aliveColor: NSColor = .green
    @State private var deadColor: NSColor = NSColor(white: 0.05, alpha: 1)
    @State private var hoveredCell: (row: Int, col: Int)?
    @State private var shapePreview: (r0: Int, c0: Int, r1: Int, c1: Int)?
    @State private var displayZoom: CGFloat = 8
    @State private var gridViewRef: GridCanvasNSView?

    @Environment(\.dismiss) private var dismiss

    private var canvas: CanvasModel? {
        state.canvases.first(where: { $0.id == canvasID })
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            gridCanvas
            Divider()
            statusBar
        }
        .frame(minWidth: 680, idealWidth: 800, minHeight: 480, idealHeight: 600)
        .onAppear(perform: loadGridState)
        .onDisappear(perform: flushAndResume)
        .onExitCommand(perform: { dismiss() })
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(DrawTool.allCases, id: \.self) { tool in
                Button(action: {
                    selectedTool = tool
                    if tool != .pencil { selectedPattern = nil }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tool.iconName)
                        Text(tool.label)
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .tint(selectedTool == tool ? .accentColor : nil)
                .opacity(selectedTool == tool ? 1.0 : 0.5)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Menu {
                ForEach(Pattern.allPatterns) { pattern in
                    Button(pattern.name) {
                        selectedPattern = pattern
                        selectedTool = .pencil
                    }
                }
                Divider()
                Button("None") {
                    selectedPattern = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.3x3")
                    Text(selectedPattern?.name ?? "Patterns")
                        .frame(maxWidth: 90)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Button(action: { gridViewRef?.adjustZoom(0.5) }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Zoom Out")

            Text("\(Int(displayZoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 40)

            Button(action: { gridViewRef?.adjustZoom(2.0) }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Zoom In")

            Button(action: { gridViewRef?.resetView() }) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Fit to view")

            Toggle(isOn: $showGridLines) {
                Image(systemName: "grid")
            }
            .toggleStyle(.button)
            .help("Toggle grid lines")

            Spacer()

            HStack(spacing: 4) {
                Text("Density:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $density, in: 0.1...0.9, step: 0.05)
                    .frame(width: 70)
            }

            Button("Random") {
                randomSeed()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clear") {
                clearAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var gridCanvas: some View {
        GridCanvasView(
            grid: $grid,
            gridW: gridW,
            gridH: gridH,
            cellSize: cellSize,
            initialZoom: displayZoom,
            showGridLines: showGridLines,
            aliveColor: aliveColor,
            deadColor: deadColor,
            selectedTool: selectedTool,
            selectedPattern: selectedPattern,
            hoveredCell: $hoveredCell,
            shapePreview: $shapePreview,
            onZoomChange: { displayZoom = $0 },
            onViewReady: { gridViewRef = $0 },
            onGridChanged: { newGrid in
                grid = newGrid
            },
            onCellAction: { row, col, tool in
                handleCellAction(row: row, col: col, tool: tool)
            },
            onShapeComplete: { r0, c0, r1, c1, tool in
                handleShapeComplete(fromRow: r0, fromCol: c0, toRow: r1, toCol: c1, tool: tool)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text("\(gridW)\u{00D7}\(gridH) cells")
                .font(.caption)
                .foregroundColor(.secondary)

            if let hover = hoveredCell {
                Text("Cursor: (\(hover.col), \(hover.row))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Scroll to zoom  \u{2022}  Right-drag to pan  \u{2022}  Esc to close")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func loadGridState() {
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            provider.pause()

            let w = provider.gridWidth
            let h = provider.gridHeight
            let snapshot = provider.gridSnapshot()

            DispatchQueue.main.async {
                if w > 0, h > 0 {
                    self.gridW = w
                    self.gridH = h
                    self.grid = snapshot
                }
            }
        }

        if gridW == 0 || gridH == 0, let canvas = canvas {
            let w = max(1, Int(floor(canvas.frame.width / CGFloat(cellSize))))
            let h = max(1, Int(floor(canvas.frame.height / CGFloat(cellSize))))
            gridW = w
            gridH = h
            grid = Array(repeating: 0, count: w * h)

            if let config = canvas.gameOfLifeConfig {
                cellSize = config.cellSize
                aliveColor = NSColor(
                    red: config.aliveColor.red,
                    green: config.aliveColor.green,
                    blue: config.aliveColor.blue,
                    alpha: config.aliveColor.alpha
                )
                deadColor = NSColor(
                    red: config.deadColor.red,
                    green: config.deadColor.green,
                    blue: config.deadColor.blue,
                    alpha: config.deadColor.alpha
                )
            }
        }
    }

    private func flushToProvider() {
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            provider.writeFullGrid(grid)
        }
    }

    private func flushAndResume() {
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            provider.writeFullGrid(grid)
            provider.resume()
        }
    }

    private func handleCellAction(row: Int, col: Int, tool: DrawTool) {
        guard row >= 0, row < gridH, col >= 0, col < gridW else { return }

        if let pattern = selectedPattern {
            placePattern(pattern, atRow: row, atCol: col)
            selectedPattern = nil
        }
    }

    private func handleShapeComplete(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int, tool: DrawTool) {
        let alive = tool != .eraser

        switch tool {
        case .line:
            DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
                provider.drawLine(fromRow: fromRow, fromCol: fromCol, toRow: toRow, toCol: toCol, alive: alive)
            }
        case .rectangle:
            let minR = min(fromRow, toRow)
            let maxR = max(fromRow, toRow)
            let minC = min(fromCol, toCol)
            let maxC = max(fromCol, toCol)
            DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
                provider.fillRect(minRow: minR, minCol: minC, maxRow: maxR, maxCol: maxC, alive: alive)
            }
        case .pencil, .eraser:
            break
        }

        refreshGridFromProvider()
    }

    private func placePattern(_ pattern: Pattern, atRow row: Int, atCol col: Int) {
        for (dr, dc) in pattern.cells {
            let r = row + dr
            let c = col + dc
            if r >= 0, r < gridH, c >= 0, c < gridW {
                let idx = r * gridW + c
                grid[idx] = 1
            }
        }
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            for (dr, dc) in pattern.cells {
                let r = row + dr
                let c = col + dc
                if r >= 0, r < gridH, c >= 0, c < gridW {
                    provider.setCell(row: r, col: c, alive: true)
                }
            }
        }
    }

    private func randomSeed() {
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            provider.randomSeed(density: density)
        }
        refreshGridFromProvider()
    }

    private func clearAll() {
        grid = Array(repeating: 0, count: gridW * gridH)
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            provider.clearAll()
        }
    }

    private func refreshGridFromProvider() {
        DesktopCanvas.shared.withGoLProvider(for: canvasID) { provider in
            let snapshot = provider.gridSnapshot()
            DispatchQueue.main.async {
                if snapshot.count == self.gridW * self.gridH {
                    self.grid = snapshot
                }
            }
        }
    }
}

struct GridCanvasView: NSViewRepresentable {
    @Binding var grid: [UInt8]
    let gridW: Int
    let gridH: Int
    let cellSize: Int
    var initialZoom: CGFloat
    let showGridLines: Bool
    let aliveColor: NSColor
    let deadColor: NSColor
    let selectedTool: DrawTool
    let selectedPattern: Pattern?
    @Binding var hoveredCell: (row: Int, col: Int)?
    @Binding var shapePreview: (r0: Int, c0: Int, r1: Int, c1: Int)?
    var onZoomChange: (CGFloat) -> Void
    var onViewReady: (GridCanvasNSView) -> Void
    var onGridChanged: ([UInt8]) -> Void
    var onCellAction: (Int, Int, DrawTool) -> Void
    var onShapeComplete: (Int, Int, Int, Int, DrawTool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCellAction: onCellAction,
            onShapeComplete: onShapeComplete,
            onGridChanged: onGridChanged
        )
    }

    func makeNSView(context: Context) -> GridCanvasNSView {
        let view = GridCanvasNSView()
        view.coordinator = context.coordinator
        view.onZoomChange = onZoomChange
        view.initialZoom = initialZoom
        DispatchQueue.main.async { onViewReady(view) }
        return view
    }

    func updateNSView(_ nsView: GridCanvasNSView, context: Context) {
        nsView.coordinator = context.coordinator
        nsView.coordinator?.onCellAction = onCellAction
        nsView.coordinator?.onShapeComplete = onShapeComplete
        nsView.coordinator?.onGridChanged = onGridChanged
        nsView.onZoomChange = onZoomChange
        nsView.grid = grid
        nsView.gridW = gridW
        nsView.gridH = gridH
        nsView.cellSize = cellSize
        nsView.showGridLines = showGridLines
        nsView.aliveColor = aliveColor
        nsView.deadColor = deadColor
        nsView.selectedTool = selectedTool
        nsView.selectedPattern = selectedPattern
        nsView.onHoverChange = { hoveredCell = $0 }
        nsView.onShapePreviewChange = { shapePreview = $0 }
        nsView.needsDisplay = true
    }

    final class Coordinator {
        var onCellAction: (Int, Int, DrawTool) -> Void
        var onShapeComplete: (Int, Int, Int, Int, DrawTool) -> Void
        var onGridChanged: ([UInt8]) -> Void

        init(
            onCellAction: @escaping (Int, Int, DrawTool) -> Void,
            onShapeComplete: @escaping (Int, Int, Int, Int, DrawTool) -> Void,
            onGridChanged: @escaping ([UInt8]) -> Void
        ) {
            self.onCellAction = onCellAction
            self.onShapeComplete = onShapeComplete
            self.onGridChanged = onGridChanged
        }
    }
}

final class GridCanvasNSView: NSView {
    var coordinator: GridCanvasView.Coordinator?
    var grid: [UInt8] = []
    var gridW: Int = 0
    var gridH: Int = 0
    var cellSize: Int = 8
    var showGridLines: Bool = true
    var aliveColor: NSColor = .green
    var deadColor: NSColor = NSColor(white: 0.05, alpha: 1)
    var selectedTool: DrawTool = .pencil
    var selectedPattern: Pattern?
    var onHoverChange: (((row: Int, col: Int)?) -> Void)?
    var onShapePreviewChange: (((r0: Int, c0: Int, r1: Int, c1: Int)?) -> Void)?
    var onZoomChange: ((CGFloat) -> Void)?
    var initialZoom: CGFloat = 8

    private var zoomLevel: CGFloat = 8
    private var panOffset: CGPoint = .zero
    private var needsInitialFit = true

    private var lastHoveredCell: (row: Int, col: Int)?
    private var lastShapePreview: (r0: Int, c0: Int, r1: Int, c1: Int)?
    private var isRightDragging = false
    private var isDrawing = false
    private var drawStartCell: (row: Int, col: Int)?
    private var lastDrawnCell: (row: Int, col: Int)?
    private var trackingArea: NSTrackingArea?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.masksToBounds = true
        if window != nil {
            zoomLevel = initialZoom
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    func adjustZoom(_ factor: CGFloat) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let newZoom = min(max(zoomLevel * factor, 0.25), 32)
        panOffset.x = center.x - (center.x - panOffset.x) * (newZoom / zoomLevel)
        panOffset.y = center.y - (center.y - panOffset.y) * (newZoom / zoomLevel)
        zoomLevel = newZoom
        onZoomChange?(zoomLevel)
        needsDisplay = true
    }

    func resetView() {
        needsInitialFit = true
        needsDisplay = true
    }

    private func applyInitialFit() {
        guard gridW > 0, gridH > 0, bounds.width > 0, bounds.height > 0 else { return }

        let fitZoom = min(bounds.width / CGFloat(gridW * cellSize),
                          bounds.height / CGFloat(gridH * cellSize))
        zoomLevel = min(max(fitZoom, 0.25), 32)

        let fittedW = CGFloat(gridW * cellSize) * zoomLevel
        let fittedH = CGFloat(gridH * cellSize) * zoomLevel
        panOffset = CGPoint(
            x: (bounds.width - fittedW) / 2,
            y: (bounds.height - fittedH) / 2
        )
        onZoomChange?(zoomLevel)
        needsInitialFit = false
    }

    private func cellAtPoint(_ point: CGPoint) -> (row: Int, col: Int) {
        let cellDisplaySize = CGFloat(cellSize) * zoomLevel
        let col = Int(floor((point.x - panOffset.x) / cellDisplaySize))
        let row = Int(floor((point.y - panOffset.y) / cellDisplaySize))
        return (row, col)
    }

    private func isValidCell(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < gridH && col >= 0 && col < gridW
    }

    private func drawCell(_ row: Int, _ col: Int, alive: Bool) {
        guard isValidCell(row, col) else { return }
        let idx = row * gridW + col
        let value: UInt8 = alive ? 1 : 0
        if grid[idx] != value {
            grid[idx] = value
        }
    }

    private func fillLine(from r0: Int, _ c0: Int, to r1: Int, _ c1: Int, alive: Bool) {
        var r = r0
        var c = c0
        let dr = abs(r1 - r0)
        let dc = abs(c1 - c0)
        let sr = r0 < r1 ? 1 : -1
        let sc = c0 < c1 ? 1 : -1
        var err = dr - dc

        while true {
            drawCell(r, c, alive: alive)
            if r == r1, c == c1 { break }
            let e2 = 2 * err
            if e2 > -dc { err -= dc; r += sr }
            if e2 < dr { err += dr; c += sc }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        isRightDragging = true
        NSCursor.closedHand.set()
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard isRightDragging else { return }
        panOffset.x += event.deltaX
        panOffset.y -= event.deltaY
        needsDisplay = true
    }

    override func rightMouseUp(with event: NSEvent) {
        isRightDragging = false
        NSCursor.arrow.set()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    override func scrollWheel(with event: NSEvent) {
        let mousePoint = convert(event.locationInWindow, from: nil)
        let factor: CGFloat = event.deltaY > 0 ? 1.0 / 1.1 : 1.1

        let newZoom = min(max(zoomLevel * factor, 0.25), 32)
        panOffset.x = mousePoint.x - (mousePoint.x - panOffset.x) * (newZoom / zoomLevel)
        panOffset.y = mousePoint.y - (mousePoint.y - panOffset.y) * (newZoom / zoomLevel)
        zoomLevel = newZoom
        onZoomChange?(zoomLevel)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let (row, col) = cellAtPoint(point)

        guard isValidCell(row, col) else { return }

        switch selectedTool {
        case .pencil:
            isDrawing = true
            lastDrawnCell = (row, col)
            drawCell(row, col, alive: true)
            needsDisplay = true
        case .eraser:
            isDrawing = true
            lastDrawnCell = (row, col)
            drawCell(row, col, alive: false)
            needsDisplay = true
        case .line, .rectangle:
            if selectedPattern != nil {
                coordinator?.onCellAction(row, col, selectedTool)
            } else {
                isDrawing = true
                drawStartCell = (row, col)
                let preview = (row, col, row, col)
                lastShapePreview = preview
                onShapePreviewChange?(preview)
                needsDisplay = true
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        let point = convert(event.locationInWindow, from: nil)
        let (row, col) = cellAtPoint(point)

        switch selectedTool {
        case .pencil:
            if let last = lastDrawnCell, isValidCell(row, col) {
                fillLine(from: last.row, last.col, to: row, col, alive: true)
                lastDrawnCell = (row, col)
                needsDisplay = true
            }
        case .eraser:
            if let last = lastDrawnCell, isValidCell(row, col) {
                fillLine(from: last.row, last.col, to: row, col, alive: false)
                lastDrawnCell = (row, col)
                needsDisplay = true
            }
        case .line, .rectangle:
            if let start = drawStartCell {
                let preview = (start.row, start.col, row, col)
                lastShapePreview = preview
                onShapePreviewChange?(preview)
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        isDrawing = false

        let point = convert(event.locationInWindow, from: nil)
        let (row, col) = cellAtPoint(point)

        switch selectedTool {
        case .pencil, .eraser:
            lastDrawnCell = nil
            coordinator?.onGridChanged(grid)

        case .line:
            if let start = drawStartCell {
                fillLine(from: start.row, start.col, to: row, col, alive: true)
                coordinator?.onShapeComplete(start.row, start.col, row, col, selectedTool)
                drawStartCell = nil
                lastShapePreview = nil
                onShapePreviewChange?(nil)
            }

        case .rectangle:
            if let start = drawStartCell {
                let minR = min(start.row, row)
                let maxR = max(start.row, row)
                let minC = min(start.col, col)
                let maxC = max(start.col, col)
                for r in minR...maxR {
                    for c in minC...maxC {
                        drawCell(r, c, alive: true)
                    }
                }
                coordinator?.onShapeComplete(start.row, start.col, row, col, selectedTool)
                drawStartCell = nil
                lastShapePreview = nil
                onShapePreviewChange?(nil)
            }
        }

        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let (row, col) = cellAtPoint(point)
        if isValidCell(row, col) {
            let cell = (row, col)
            lastHoveredCell = cell
            onHoverChange?(cell)
        } else {
            lastHoveredCell = nil
            onHoverChange?(nil)
        }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        lastHoveredCell = nil
        onHoverChange?(nil)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if needsInitialFit {
            applyInitialFit()
        }

        let bgColor: NSColor = .controlBackgroundColor
        bgColor.setFill()
        bounds.fill()

        guard gridW > 0, gridH > 0 else { return }

        let cellDisplaySize = CGFloat(cellSize) * zoomLevel
        let context = NSGraphicsContext.current!.cgContext

        if grid.count >= gridW * gridH {
            for row in 0..<gridH {
                for col in 0..<gridW {
                    let idx = row * gridW + col
                    let isAlive = grid[idx] != 0
                    let rect = CGRect(
                        x: panOffset.x + CGFloat(col) * cellDisplaySize,
                        y: panOffset.y + CGFloat(row) * cellDisplaySize,
                        width: cellDisplaySize,
                        height: cellDisplaySize
                    )

                    if !dirtyRect.intersects(rect) { continue }

                    (isAlive ? aliveColor : deadColor).setFill()
                    context.fill(rect)
                }
            }
        }

        if showGridLines, cellDisplaySize >= 4 {
            NSColor.quaternaryLabelColor.setStroke()
            context.setLineWidth(0.5)

            let minCol = max(0, Int(floor((dirtyRect.minX - panOffset.x) / cellDisplaySize)))
            let maxCol = min(gridW, Int(ceil((dirtyRect.maxX - panOffset.x) / cellDisplaySize)))
            let minRow = max(0, Int(floor((dirtyRect.minY - panOffset.y) / cellDisplaySize)))
            let maxRow = min(gridH, Int(ceil((dirtyRect.maxY - panOffset.y) / cellDisplaySize)))

            for col in minCol...maxCol {
                let x = panOffset.x + CGFloat(col) * cellDisplaySize
                context.move(to: CGPoint(x: x, y: panOffset.y + CGFloat(minRow) * cellDisplaySize))
                context.addLine(to: CGPoint(x: x, y: panOffset.y + CGFloat(maxRow) * cellDisplaySize))
            }
            for row in minRow...maxRow {
                let y = panOffset.y + CGFloat(row) * cellDisplaySize
                context.move(to: CGPoint(x: panOffset.x + CGFloat(minCol) * cellDisplaySize, y: y))
                context.addLine(to: CGPoint(x: panOffset.x + CGFloat(maxCol) * cellDisplaySize, y: y))
            }
            context.strokePath()
        }

        if let (hoverRow, hoverCol) = lastHoveredCell,
           isValidCell(hoverRow, hoverCol) {
            let hoverRect = CGRect(
                x: panOffset.x + CGFloat(hoverCol) * cellDisplaySize,
                y: panOffset.y + CGFloat(hoverRow) * cellDisplaySize,
                width: cellDisplaySize,
                height: cellDisplaySize
            )
            NSColor.controlAccentColor.withAlphaComponent(0.3).setFill()
            context.fill(hoverRect)
        }

        if let (r0, c0, r1, c1) = lastShapePreview {
            switch selectedTool {
            case .line:
                let x0 = panOffset.x + (CGFloat(c0) + 0.5) * cellDisplaySize
                let y0 = panOffset.y + (CGFloat(r0) + 0.5) * cellDisplaySize
                let x1 = panOffset.x + (CGFloat(c1) + 0.5) * cellDisplaySize
                let y1 = panOffset.y + (CGFloat(r1) + 0.5) * cellDisplaySize
                NSColor.systemYellow.withAlphaComponent(0.5).setStroke()
                context.setLineWidth(2)
                context.move(to: CGPoint(x: x0, y: y0))
                context.addLine(to: CGPoint(x: x1, y: y1))
                context.strokePath()
                return
            case .rectangle:
                let minC = min(c0, c1)
                let maxC = max(c0, c1)
                let minR = min(r0, r1)
                let maxR = max(r0, r1)
                let previewRect = CGRect(
                    x: panOffset.x + CGFloat(minC) * cellDisplaySize,
                    y: panOffset.y + CGFloat(minR) * cellDisplaySize,
                    width: CGFloat(maxC - minC + 1) * cellDisplaySize,
                    height: CGFloat(maxR - minR + 1) * cellDisplaySize
                )
                NSColor.systemYellow.withAlphaComponent(0.25).setFill()
                context.fill(previewRect)
                NSColor.systemYellow.withAlphaComponent(0.6).setStroke()
                context.setLineWidth(1.5)
                context.stroke(previewRect)
            case .pencil, .eraser:
                break
            }
        }
    }
}