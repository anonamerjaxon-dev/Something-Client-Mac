import SwiftUI
import DesktopCanvas

struct EditorView: View {
    @StateObject private var state = EditorState()

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            HSplitView {
                CanvasListView(state: state)
                    .frame(minWidth: 160, idealWidth: 200)

                visualLayoutPanel
                    .frame(minWidth: 280)

                CanvasSettingsView(state: state)
                    .frame(minWidth: 200, idealWidth: 230)
            }

            Divider()

            statusBar
                .frame(height: 28)
        }
        .frame(minWidth: 800, minHeight: 550)
        .onAppear {
            if state.canvases.isEmpty {
                state.loadLastSession()
            }
        }
        .sheet(isPresented: $state.showPresetManager) {
            PresetManagerView(state: state)
        }
        .sheet(isPresented: $state.showGridEditor) {
            if let canvasID = state.gridEditorCanvasID {
                GridEditorView(canvasID: canvasID, state: state)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            if state.isApplied {
                Button(action: state.stopDesktop) {
                    Label("Stop", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .help("Stop and remove from desktop")

                Button(action: state.applyToDesktop) {
                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help("Refresh desktop")
            } else {
                Button(action: state.applyToDesktop) {
                    Label("Apply to Desktop", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Menu {
                Button(action: state.addGameOfLifeCanvas) {
                    Label("Game of Life", systemImage: "circle.grid.cross")
                }
                Button(action: state.addVideoCanvas) {
                    Label("Video", systemImage: "play.rectangle")
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Add canvas")

            Button(action: state.removeSelectedCanvas) {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedCanvasID == nil)
            .help("Remove selected canvas")

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Button(action: state.fillScreen) {
                Label("Fill Screen", systemImage: "rectangle.portrait.arrowtriangle.2.outward")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedCanvasID == nil)
            .help("Fill canvas to screen size")

            Button(action: state.centerCanvas) {
                Label("Center", systemImage: "crop")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedCanvasID == nil)
            .help("Center canvas on screen")

            Spacer()

            Toggle(isOn: $state.snapEnabled) {
                Image(systemName: "grid")
            }
            .toggleStyle(.button)
            .help("Toggle snap to grid")

            Button(action: { state.showPresetManager = true }) {
                Label("Presets", systemImage: "folder")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Preset manager")

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            ColorPicker("Background", selection: backgroundColorBinding)
                .labelsHidden()
                .frame(width: 28)

            if state.backgroundColor != nil {
                Button(action: { state.backgroundColor = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove background fill")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var visualLayoutPanel: some View {
        VStack(spacing: 0) {
            if state.canvases.isEmpty {
                emptyState
            } else {
                VisualLayoutView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No canvases yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Click + to add a Game of Life or Video canvas.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)

            Text(state.statusMessage.isEmpty ? readyLabel : state.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Text("\(state.canvases.count) canvas\(state.canvases.count == 1 ? "" : "es")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .background(statusBarBackground)
    }

    private var statusDotColor: Color {
        switch state.statusType {
        case .info: return state.isApplied ? .green : .gray
        case .warning: return .yellow
        case .error: return .red
        }
    }

    private var statusBarBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding<Color>(
            get: {
                if let bg = state.backgroundColor {
                    Color(nsColor: bg.nsColor)
                } else {
                    Color.clear
                }
            },
            set: { newColor in
                if let resolved = NSColor(newColor).usingColorSpace(.sRGB) {
                    state.backgroundColor = CodableColor(
                        red: Double(resolved.redComponent),
                        green: Double(resolved.greenComponent),
                        blue: Double(resolved.blueComponent),
                        alpha: 1.0
                    )
                }
            }
        )
    }

    private var readyLabel: String {
        state.isApplied ? "Running on desktop" : "Ready"
    }
}