import SwiftUI
import Combine

/// Transparent overlay window that floats above normal app content.
final class TrailWindow: NSWindow {

    var hostingController: NSHostingController<TrailContentView>!
    let model: TrailModel

    init(configuration: TrailConfiguration = .init()) {
        self.model = TrailModel()
        let contentView = TrailContentView(configuration: configuration, model: model)
        let hc = NSHostingController(rootView: contentView)
        self.hostingController = hc

        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.contentViewController = hc
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ points: RingBuffer<TrailPoint>) {
        model.trailPoints = points
    }
}

/// Shared reactive model so SwiftUI views can observe trail point changes.
final class TrailModel: ObservableObject {
    @Published var trailPoints: RingBuffer<TrailPoint> = .init(capacity: 100)
}

/// SwiftUI view that hosts the Canvas for rendering the trail.
struct TrailContentView: View {
    @ObservedObject var model: TrailModel
    private let renderer: TrailRenderer

    init(configuration: TrailConfiguration = .init(), model: TrailModel) {
        self.renderer = TrailRenderer(configuration: configuration)
        self.model = model
    }

    var body: some View {
        Canvas { context, size in
            renderer.draw(context: context, points: model.trailPoints)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
