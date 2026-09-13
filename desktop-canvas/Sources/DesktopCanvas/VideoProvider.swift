import AppKit
import AVFoundation
import QuartzCore

final class VideoProvider: CanvasProvider {
    var canvas: CanvasModel

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var placeholderView: NSView?
    private var loopObserver: NSObjectProtocol?
    private var occlusionObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var ownerView: NSView?
    private var playbackDeferred = true

    init(canvas: CanvasModel) {
        self.canvas = canvas
    }

    func attach(to superview: NSView, frame: NSRect) {
        guard let config = canvas.videoConfig else { return }
        ownerView = superview

        let fileExists = FileManager.default.fileExists(atPath: config.videoURL.path)

        if !fileExists || config.videoURL.path.isEmpty {
            showPlaceholder(in: superview, frame: frame)
            return
        }

        let asset = AVAsset(url: config.videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none
        player.volume = Float(config.volume)
        self.player = player

        let layer = AVPlayerLayer()
        layer.player = player
        layer.frame = frame
        layer.videoGravity = .resizeAspectFill
        superview.layer?.addSublayer(layer)
        self.playerLayer = layer

        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .failed {
                DispatchQueue.main.async {
                    self.showPlaceholder(in: superview, frame: superview.bounds,
                                         message: "Playback failed: \(item.error?.localizedDescription ?? "unknown")")
                }
            }
        }

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self, let player = self.player, self.playerLayer?.superlayer != nil else { return }
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished { player.play() }
            }
        }

        observeWindowOcclusion(superview)

        playbackDeferred = true
    }

    private func observeWindowOcclusion(_ superview: NSView) {
        guard let window = superview.window else { return }

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self, let window = self.ownerView?.window else { return }
            if window.occlusionState.contains(.visible) {
                self.player?.play()
            } else {
                self.player?.pause()
            }
        }
    }

    private func showPlaceholder(in superview: NSView, frame: NSRect, message: String = "Missing Video") {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        statusObserver?.invalidate()
        statusObserver = nil
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.darkGray.cgColor

        let label = NSTextField(labelWithString: "\u{26A0} \(message)")
        label.textColor = NSColor.lightGray
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 14)
        label.frame = container.bounds
        label.autoresizingMask = [.width, .height]
        container.addSubview(label)

        superview.addSubview(container)
        self.placeholderView = container
    }

    func detach() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        if let observer = occlusionObserver {
            NotificationCenter.default.removeObserver(observer)
            occlusionObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        ownerView = nil
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        placeholderView?.removeFromSuperview()
        placeholderView = nil
    }

    func update() {
        playerLayer?.frame = NSRect(origin: .zero, size: canvas.frame.size)
        if let volume = canvas.videoConfig?.volume {
            player?.volume = Float(volume)
        }
        if playbackDeferred, canvas.frame.size.width > 0, canvas.frame.size.height > 0 {
            playbackDeferred = false
            player?.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }
}