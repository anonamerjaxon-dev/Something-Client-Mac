import AppKit

final class CanvasRenderer: NSView {
    weak var provider: CanvasProvider?

    init(provider: CanvasProvider) {
        self.provider = provider
        super.init(frame: .zero)
        self.wantsLayer = true
        provider.attach(to: self, frame: self.bounds)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize.width > 0 && newSize.height > 0 {
            self.layer?.masksToBounds = true
        }
        provider?.update()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            provider?.detach()
        }
    }

    deinit {
        provider?.detach()
    }
}