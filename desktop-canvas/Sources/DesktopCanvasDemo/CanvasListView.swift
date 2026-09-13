import SwiftUI
import DesktopCanvas

struct CanvasListView: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.selectedCanvasID) {
                ForEach(state.canvases) { canvas in
                    CanvasRowView(canvas: canvas)
                        .tag(canvas.id)
                }
                .onMove(perform: state.moveCanvas)
            }
            .listStyle(.inset)
            .frame(minWidth: 200)

            Divider()

            HStack(spacing: 4) {
                addGoLButton
                addVideoButton
                Spacer()
                removeButton
            }
            .padding(8)
        }
    }

    private var addGoLButton: some View {
        Button(action: state.addGameOfLifeCanvas) {
            Image(systemName: "circle.grid.3x3")
        }
        .buttonStyle(.borderless)
        .help("Add Game of Life canvas")
    }

    private var addVideoButton: some View {
        Button(action: state.addVideoCanvas) {
            Image(systemName: "play.rectangle")
        }
        .buttonStyle(.borderless)
        .help("Add Video canvas")
    }

    private var removeButton: some View {
        Button(action: state.removeSelectedCanvas) {
            Image(systemName: "minus")
        }
        .buttonStyle(.borderless)
        .help("Remove selected canvas")
        .disabled(state.selectedCanvasID == nil)
    }
}

struct CanvasRowView: View {
    let canvas: CanvasModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(canvasName)
                    .font(.body)
                Text(sizeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch canvas.type {
        case .gameOfLife: return "circle.grid.3x3"
        case .video: return "play.rectangle"
        }
    }

    private var iconColor: Color {
        switch canvas.type {
        case .gameOfLife: return .green
        case .video: return .blue
        }
    }

    private var canvasName: String {
        switch canvas.type {
        case .gameOfLife: return "Game of Life"
        case .video: return "Video"
        }
    }

    private var sizeLabel: String {
        "\(Int(canvas.frame.width))×\(Int(canvas.frame.height))"
    }
}