import AppKit

final class ScreenManager {
    private(set) var windows: [NSScreen: CanvasWindow] = [:]
    private var layout: CanvasLayout?
    private var displayObserver: NSObjectProtocol?

    func applyEmbedded(layout: CanvasLayout) {
        self.layout = layout

        NSApplication.shared.setActivationPolicy(.accessory)

        for screen in NSScreen.screens {
            createWindow(for: screen)
        }

        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    func stop() {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
            displayObserver = nil
        }

        for (_, window) in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    func refresh() {
        guard let layout = layout else { return }
        for (_, window) in windows {
            window.layoutCanvases(layout.canvases)
        }
    }

    private func createWindow(for screen: NSScreen) {
        guard let layout = layout else { return }
        let window = CanvasWindow(screen: screen)
        window.layoutCanvases(layout.canvases)
        windows[screen] = window
    }

    private func handleScreenChange() {
        let currentScreens = Set(NSScreen.screens)

        for (screen, window) in windows {
            if !currentScreens.contains(screen) {
                window.orderOut(nil)
                windows[screen] = nil
            }
        }

        for screen in currentScreens {
            if windows[screen] == nil {
                createWindow(for: screen)
            }
        }
    }
}