import AppKit

protocol CanvasProvider: AnyObject {
    var canvas: CanvasModel { get set }

    func attach(to superview: NSView, frame: NSRect)
    func detach()
    func update()
    func pause()
    func resume()
}

extension CanvasProvider {
    func pause() {}
    func resume() {}
}