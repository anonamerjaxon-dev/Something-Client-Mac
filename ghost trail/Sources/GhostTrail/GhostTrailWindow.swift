import AppKit
import SwiftUI

final class GhostTrailWindow: NSWindow {
    private let model: GhostTrailModel

    init(configuration: GhostTrailConfiguration) {
        let model = GhostTrailModel()
        let renderer = GhostTrailRenderer(configuration: configuration)
        let contentView = GhostTrailContentView(model: model, renderer: renderer)
        let hostingController = NSHostingController(rootView: contentView)

        self.model = model

        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.contentViewController = hostingController
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        switch configuration.windowLevel {
        case .aboveWindows:
            self.level = .floating
        case .behindWindows:
            self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        }

        guard let screen = NSScreen.main else {
            fatalError("GhostTrail requires at least one display")
        }
        self.setFrame(screen.frame, display: true)
        hostingController.view.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingController.view.autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(trails: [CGWindowID: RingBuffer<TrailFrame>]) {
        model.trails = trails
    }
}

final class GhostTrailModel: ObservableObject {
    @Published var trails: [CGWindowID: RingBuffer<TrailFrame>] = [:]
}

struct GhostTrailContentView: View {
    @ObservedObject var model: GhostTrailModel
    let renderer: GhostTrailRenderer

    var body: some View {
        Canvas { context, size in
            renderer.draw(context: context, trails: model.trails, size: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}