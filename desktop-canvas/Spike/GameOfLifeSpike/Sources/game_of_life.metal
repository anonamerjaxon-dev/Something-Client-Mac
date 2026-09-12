#include <metal_stdlib>
using namespace metal;

struct GridParams {
    uint width;
    uint height;
    uint totalCells;
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
            if (inputGrid[nidx] != 0) {
                aliveNeighbors++;
            }
        }
    }

    uint8_t cell = inputGrid[idx];
    uint8_t nextState = 0;

    if (cell != 0) {
        if (aliveNeighbors == 2 || aliveNeighbors == 3) {
            nextState = 1;
        }
    } else {
        if (aliveNeighbors == 3) {
            nextState = 1;
        }
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
    float2 uvs[6] = {
        float2(0.0, 0.0), float2(1.0, 0.0), float2(0.0, 1.0),
        float2(1.0, 0.0), float2(1.0, 1.0), float2(0.0, 1.0)
    };

    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = uvs[vid];
    return out;
}

struct FragmentParams {
    uint gridWidth;
    uint gridHeight;
    float cellSize;
};

fragment float4 gameOfLifeFragment(
    VertexOut              in       [[stage_in]],
    constant FragmentParams& params [[buffer(0)]],
    device const uint8_t*   grid    [[buffer(1)]],
    float2                  fragPos [[frame_interpolated, center_no_perspective]]
) {
    uint col = uint(floor(fragPos.x / params.cellSize));
    uint row = uint(floor(fragPos.y / params.cellSize));

    if (col >= params.gridWidth || row >= params.gridHeight) {
        return float4(0.1, 0.1, 0.1, 1.0);
    }

    uint idx = row * params.gridWidth + col;
    bool alive = grid[idx] != 0;

    if (alive) {
        return float4(0.0, 1.0, 0.0, 1.0);
    } else {
        return float4(0.15, 0.15, 0.15, 1.0);
    }
}