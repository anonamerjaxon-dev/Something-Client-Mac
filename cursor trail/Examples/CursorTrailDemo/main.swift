import SwiftUI
import CursorTrail

@main
struct CursorTrailDemoApp: App {
    @StateObject private var trailController = TrailController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: trailController)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.automatic)
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
        VStack(spacing: 20) {
            Text("Cursor Trail")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Style:")
                        .frame(width: 80, alignment: .leading)
                    Picker("Style", selection: $controller.style) {
                        Text("Line").tag(TrailStyle.line)
                        Text("Ribbon").tag(TrailStyle.ribbon)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                HStack {
                    Text("Color:")
                        .frame(width: 80, alignment: .leading)
                    Picker("Color", selection: $controller.colorIndex) {
                        ForEach(0..<controller.colorOptions.count, id: \.self) { i in
                            Text(controller.colorOptions[i].0).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Trail Length:")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $controller.trailLength, in: 1...50, step: 1)
                        .frame(width: 150)
                    Text("\(Int(controller.trailLength))")
                        .frame(width: 35, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Fade Speed:")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $controller.fadeSpeed, in: 0.5...5, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", controller.fadeSpeed))
                        .frame(width: 35, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Thickness:")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $controller.thickness, in: 1...40, step: 0.5)
                        .frame(width: 150)
                    Text(String(format: "%.1f", controller.thickness))
                        .frame(width: 35, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Rainbow Speed:")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $controller.rainbowSpeed, in: 0.1...5, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", controller.rainbowSpeed))
                        .frame(width: 35, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Diminishing:")
                        .frame(width: 90, alignment: .leading)
                    Toggle("", isOn: $controller.diminishing)
                        .labelsHidden()
                    Spacer().frame(width: 120)
                }

                if controller.diminishing {
                    HStack {
                        Text("Intensity:")
                            .frame(width: 90, alignment: .leading)
                        Slider(value: $controller.diminishingIntensity, in: 0.0...1.0, step: 0.05)
                            .frame(width: 150)
                        Text(String(format: "%.2f", controller.diminishingIntensity))
                            .frame(width: 35, alignment: .trailing)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Opacity:")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $controller.opacity, in: 0...1, step: 0.05)
                        .frame(width: 150)
                    Text(String(format: "%.0%%", controller.opacity * 100))
                        .frame(width: 35, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(controller.isRunning)

            Divider()

            if controller.isRunning {
                Button("Stop Trail") {
                    controller.stopTrail()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Start Trail") {
                    controller.startTrail()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()

            Text("Move your mouse after starting to see the trail")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}
