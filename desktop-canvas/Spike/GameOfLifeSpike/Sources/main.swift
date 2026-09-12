import AppKit
import Metal
import MetalKit
import QuartzCore

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let metalSource = """
#include <metal_stdlib>
using namespace metal;

struct GridParams {
    uint width;
    uint height;
};

kernel void gameOfLifeStep(
    device const uint8_t* inputGrid  [[buffer(0)]],
    device uint8_t*       outputGrid [[buffer(1)]],
    constant GridParams&  params     [[buffer(2)]],
    uint2                 gid        [[thread_position_in_grid]]
) {
    if (gid.x >= params.width || gid.y >= params.height) return;
    uint idx = gid.y * params.width + gid.x;
    int aliveNeighbors = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int nx = int(gid.x) + dx;
            int ny = int(gid.y) + dy;
            if (nx < 0) nx = int(params.width) - 1;
            if (ny < 0) ny = int(params.height) - 1;
            if (nx >= int(params.width)) nx = 0;
            if (ny >= int(params.height)) ny = 0;
            uint nidx = uint(ny) * params.width + uint(nx);
            if (inputGrid[nidx] != 0) aliveNeighbors++;
        }
    }
    uint8_t cell = inputGrid[idx];
    uint8_t nextState = 0;
    if (cell != 0) {
        if (aliveNeighbors == 2 || aliveNeighbors == 3) nextState = 1;
    } else {
        if (aliveNeighbors == 3) nextState = 1;
    }
    outputGrid[idx] = nextState;
}

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fullscreenVertex(uint vid [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2( 1.0, -1.0), float2( 1.0,  1.0), float2(-1.0,  1.0)
    };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = float2(0.0);
    return out;
}

struct FragmentParams {
    uint gridWidth;
    uint gridHeight;
    float cellSize;
    float viewWidth;
    float viewHeight;
};

fragment float4 gameOfLifeFragment(
    VertexOut              in       [[stage_in]],
    constant FragmentParams& params [[buffer(0)]],
    device const uint8_t*   grid    [[buffer(1)]]
) {
    float2 fragPos = in.position.xy;
    fragPos.y = params.viewHeight - fragPos.y;
    uint col = uint(floor(fragPos.x / params.cellSize));
    uint row = uint(floor(fragPos.y / params.cellSize));
    if (col >= params.gridWidth || row >= params.gridHeight) {
        return float4(0.1, 0.1, 0.1, 1.0);
    }
    uint idx = row * params.gridWidth + col;
    bool alive = grid[idx] != 0;
    return alive ? float4(0.0, 1.0, 0.0, 1.0) : float4(0.15, 0.15, 0.15, 1.0);
}
"""

let gridWidth: UInt32 = 500
let gridHeight: UInt32 = 500
let totalCells = Int(gridWidth * gridHeight)
let cellSize: Float = 2.0

class GameOfLifeView: MTKView {
    var computePipeline: MTLComputePipelineState!
    var renderPipeline: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var bufferA: MTLBuffer!
    var bufferB: MTLBuffer!
    var useBufferA = true
    var needsCompute = true
    var depthState: MTLDepthStencilState!

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        setup()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        guard let device = device else { return }

        framebufferOnly = false
        clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        preferredFramesPerSecond = 60

        let library = try! device.makeLibrary(source: metalSource, options: nil)

        let computeFn = library.makeFunction(name: "gameOfLifeStep")!
        computePipeline = try! device.makeComputePipelineState(function: computeFn)

        let vertexFn = library.makeFunction(name: "fullscreenVertex")!
        let fragmentFn = library.makeFunction(name: "gameOfLifeFragment")!
        let rpDesc = MTLRenderPipelineDescriptor()
        rpDesc.vertexFunction = vertexFn
        rpDesc.fragmentFunction = fragmentFn
        rpDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipeline = try! device.makeRenderPipelineState(descriptor: rpDesc)

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.isDepthWriteEnabled = false
        depthDesc.depthCompareFunction = .always
        depthState = device.makeDepthStencilState(descriptor: depthDesc)

        commandQueue = device.makeCommandQueue()!

        bufferA = device.makeBuffer(length: totalCells, options: .storageModeShared)!
        bufferB = device.makeBuffer(length: totalCells, options: .storageModeShared)!

        seedGrid()

        for i in 0..<totalCells {
            bufferA.contents().advanced(by: i).storeBytes(of: UInt8(0), as: UInt8.self)
        }
        let bufB = bufferA.contents().assumingMemoryBound(to: UInt8.self)
        let seed = seedData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        for i in 0..<totalCells {
            bufB[i] = seed[i]
        }
    }

    var seedData: [UInt8] = []

    func seedGrid() {
        seedData = (0..<totalCells).map { _ in UInt8.random(in: 0...1) }
    }

    override func draw(_ rect: CGRect) {
        guard let device = device,
              let drawable = currentDrawable,
              let rpDesc = currentRenderPassDescriptor,
              let cmdBuf = commandQueue.makeCommandBuffer() else {
            return
        }

        if needsCompute {
            let inputBuffer = useBufferA ? bufferA! : bufferB!
            let outputBuffer = useBufferA ? bufferB! : bufferA!

            var params = (gridWidth, gridHeight)
            let paramsBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<(UInt32, UInt32)>.size, options: [])

            let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
            computeEncoder.setComputePipelineState(computePipeline)
            computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)

            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let gridSize = MTLSize(width: Int(gridWidth), height: Int(gridHeight), depth: 1)
            computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()

            useBufferA = !useBufferA
        }

        let renderEncoder = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)!
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setDepthStencilState(depthState)

        let currentGrid = useBufferA ? bufferA! : bufferB!
        let scale = Float(drawableSize.width / bounds.width)
        var fragParams: (UInt32, UInt32, Float, Float, Float) = (
            gridWidth, gridHeight, cellSize * scale,
            Float(drawableSize.width), Float(drawableSize.height)
        )
        let fragBuffer = device.makeBuffer(bytes: &fragParams, length: MemoryLayout<(UInt32, UInt32, Float, Float, Float)>.size, options: [])

        renderEncoder.setFragmentBuffer(fragBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(currentGrid, offset: 0, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()

        needsCompute = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowFrame = NSRect(x: 100, y: 100, width: 1000, height: 1000)
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "S0.4: Game of Life Metal Spike (500x500 grid, 2px cells)"

        let mtkView = GameOfLifeView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1000), device: MTLCreateSystemDefaultDevice())
        mtkView.clipsToBounds = true
        mtkView.wantsLayer = true
        mtkView.autoresizingMask = [.width, .height]

        window.contentView?.addSubview(mtkView)
        window.contentView?.wantsLayer = true
        window.contentView?.clipsToBounds = true

        window.setContentSize(NSSize(width: 1000, height: 1000))

        print("=== S0.4 Game of Life Metal Spike ===")
        print("Grid: \(gridWidth)x\(gridHeight) cells")
        print("Cell size: \(cellSize)px at 1000x1000 window")
        print("Check: Conway patterns (gliders, blinkers, blocks) emerging from random seed")
        print("Check: smooth 60fps, no flicker on buffer swap")

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()