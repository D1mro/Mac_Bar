import AppKit

/// Два маленьких окна-четвертькруги в нижних углах экрана (этап 5).
/// Чёрные круги скругляют видимые углы, окна не перехватывают мышь.
@MainActor
final class CornerWindows {
    static let shared = CornerWindows()

    private static let size: CGFloat = 32
    private var windows: [NSPanel] = []

    func start() {
        guard windows.isEmpty, let screen = NSScreen.main else { return }
        let s = Self.size
        for x in [screen.frame.minX, screen.frame.maxX - s] {
            let rect = NSRect(x: x, y: screen.frame.minY, width: s, height: s)
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            // kCGDesktopWindowLevel = kCGBaseWindowLevel + 5 + 20 = INT32_MIN + 25.
            panel.level = NSWindow.Level(rawValue: Int(Int32.min) + 25)
            panel.contentView = CornerView()
            panel.orderBack(nil)
            windows.append(panel)
        }
    }

    /// Чёрный круг — «четвертькруг» в углу окна.
    private final class CornerView: NSView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            layer?.cornerRadius = frame.width
            layer?.masksToBounds = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }
    }
}
