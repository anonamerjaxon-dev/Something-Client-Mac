import AppKit

final class CanvasWindow: NSWindow {

    private var renderers: [UUID: CanvasRenderer] = [:]
    private var providers: [UUID: any CanvasProvider] = [:]

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let iconLevel = CGWindowLevelForKey(.desktopIconWindow)
        self.level = NSWindow.Level(rawValue: Int(iconLevel))
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .transient,
            .ignoresCycle
        ]

        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = .clear

        self.order(.below, relativeTo: 0)
    }

    func layoutCanvases(_ canvases: [CanvasModel]) {
        guard let contentView = contentView else { return }

        let newIDs = Set(canvases.map(\.id))
        let oldIDs = Set(renderers.keys)

        for id in oldIDs.subtracting(newIDs) {
            if let provider = providers[id] {
                provider.detach()
            }
            renderers[id]?.removeFromSuperview()
            renderers[id] = nil
            providers[id] = nil
        }

        for canvas in canvases where renderers[canvas.id] == nil {
            let provider: any CanvasProvider = switch canvas.type {
            case .gameOfLife:
                GameOfLifeProvider(canvas: canvas)
            case .video:
                VideoProvider(canvas: canvas)
            }

            let renderer = CanvasRenderer(provider: provider)
            renderers[canvas.id] = renderer
            providers[canvas.id] = provider
        }

        for canvas in canvases {
            guard let renderer = renderers[canvas.id],
                  let provider = providers[canvas.id] else { continue }
            provider.canvas = canvas
            renderer.frame = canvas.frame
            provider.update()
        }

        for canvas in canvases {
            guard let renderer = renderers[canvas.id] else { continue }
            if renderer.superview !== contentView {
                contentView.addSubview(renderer)
            }
        }
    }
}