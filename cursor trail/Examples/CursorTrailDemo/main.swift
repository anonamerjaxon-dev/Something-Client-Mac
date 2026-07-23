import SwiftUI
import CursorTrail

@main
struct CursorTrailDemoApp: App {
    @StateObject private var trailController = TrailController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: trailController)
                .frame(minWidth: 420, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}

class TrailController: ObservableObject {
    @Published var isRunning = false
    @Published var style: TrailStyle = .ribbon
    @Published var colorIndex = 2
    @Published var trailLength: Double = 10
    @Published var fadeSpeed: Double = 1.0
    @Published var rainbowSpeed: Double = 5.0
    @Published var thickness: Double = 12
    @Published var diminishing = true
    @Published var diminishingIntensity: Double = 0.7
    @Published var opacity: Double = 0.8

    private var trail: CursorTrail?

    let colorOptions: [(String, TrailColor)] = [
        ("Cyan", .solid(.cyan)),
        ("Red-Blue", .gradient(.red, .blue)),
        ("Rainbow", .rainbow),
        ("Green", .solid(.green)),
        ("Purple", .solid(.purple)),
        ("Orange", .solid(.orange)),
    ]

    func startTrail() {
        guard !isRunning else { return }
        let color = colorOptions[colorIndex].1

        let builder = CursorTrail()
            .color(color)
            .thickness(CGFloat(thickness))
            .length(Int(trailLength))
            .fadeSpeed(fadeSpeed)
            .rainbowSpeed(rainbowSpeed)
            .diminishing(diminishing)
            .diminishingIntensity(diminishingIntensity)
            .opacity(opacity)
            .style(style)
            .speed(.adaptive)

        if builder.start() {
            isRunning = true
            trail = builder
        }
    }

    func stopTrail() {
        trail?.stop()
        trail = nil
        isRunning = false
    }
}

struct ContentView: View {
    @ObservedObject var controller: TrailController

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    styleSection
                    colorSection
                    appearanceSection
                    behaviorSection
                }
                .padding(20)
            }
            Divider()
            footerSection
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.title2)
                .foregroundStyle(controller.isRunning ? .blue : .secondary)
            Text("Cursor Trail")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(controller.isRunning ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(controller.isRunning ? "Active" : "Idle")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternaryLabelColor))
        )
    }

    // MARK: - Style

    private var styleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                LabeledRow("Trail Style") {
                    Picker("Style", selection: $controller.style) {
                        Text("Line").tag(TrailStyle.line)
                        Text("Ribbon").tag(TrailStyle.ribbon)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            .padding(8)
        } label: {
            SectionLabel("Style")
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                LabeledRow("Color") {
                    Picker("Color", selection: $controller.colorIndex) {
                        ForEach(0..<controller.colorOptions.count, id: \.self) { i in
                            Text(controller.colorOptions[i].0).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
            }
            .padding(8)
        } label: {
            SectionLabel("Color")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SliderRow("Thickness", value: $controller.thickness, range: 1...40, step: 0.5, format: "%.1f")
                SliderRow("Opacity", value: $controller.opacity, range: 0...1, step: 0.05, format: "%.0f%%", multiplier: 100)
                SliderRow("Trail Length", value: $controller.trailLength, range: 1...50, step: 1, format: "%.0f")
            }
            .padding(8)
        } label: {
            SectionLabel("Appearance")
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SliderRow("Fade Speed", value: $controller.fadeSpeed, range: 0.5...5, step: 0.1, format: "%.1f")

                if case .rainbow = controller.colorOptions[controller.colorIndex].1 {
                    SliderRow("Rainbow Speed", value: $controller.rainbowSpeed, range: 0.1...5, step: 0.1, format: "%.1f")
                }

                ToggleRow("Diminishing", isOn: $controller.diminishing)

                if controller.diminishing {
                    SliderRow("Intensity", value: $controller.diminishingIntensity, range: 0...1, step: 0.05, format: "%.2f")
                }
            }
            .padding(8)
        } label: {
            SectionLabel("Behavior")
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if controller.isRunning {
                Button(action: controller.stopTrail) {
                    Label("Stop Trail", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button(action: controller.startTrail) {
                    Label("Start Trail", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Reusable Components

private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
    }
}

private struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .frame(width: 110, alignment: .leading)
            content()
            Spacer()
        }
    }
}

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var multiplier: Double = 1

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String, multiplier: Double = 1) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
        self.multiplier = multiplier
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.body)
                .frame(width: 110, alignment: .leading)

            Slider(value: $value, in: range, step: step)
                .frame(maxWidth: 180)

            Text(String(format: format, value * multiplier))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

private struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .frame(width: 110, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
            Spacer()
        }
    }
}