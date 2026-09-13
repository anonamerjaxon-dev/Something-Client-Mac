import SwiftUI
import AppKit
import DesktopCanvas

struct NativeColorWell: NSViewRepresentable {
    @Binding var codableColor: CodableColor

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.color = codableColor.nsColor
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        let nsColor = codableColor.nsColor
        if nsView.color != nsColor {
            nsView.color = nsColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator {
        let parent: NativeColorWell
        init(_ parent: NativeColorWell) { self.parent = parent }
        @objc func colorChanged(_ sender: NSColorWell) {
            parent.codableColor = CodableColor(nsColor: sender.color)
        }
    }
}

extension CodableColor {
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }

    init(nsColor: NSColor) {
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
    }
}