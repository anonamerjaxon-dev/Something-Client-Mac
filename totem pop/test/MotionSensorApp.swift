import SwiftUI

@main
struct MotionSensorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 380)
        }
        .windowResizability(.contentSize)
    }
}
