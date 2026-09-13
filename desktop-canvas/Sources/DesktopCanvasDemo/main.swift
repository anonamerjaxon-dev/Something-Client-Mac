import SwiftUI

@main
struct DesktopCanvasDemoApp: App {
    var body: some Scene {
        Window("DesktopCanvas Editor", id: "editor") {
            EditorView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 700, height: 500)
    }
}