import AppKit
import AVFoundation
import CoreGraphics

/// Окно «живых обоев» на уровне рабочего стола: позади обычных окон, клики проходят насквозь.
final class LiveWallpaperWindow: NSPanel {
    init(player: AVPlayer) {
        let frame = NSScreen.main?.frame ?? .zero
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        // kCGDesktopWindowLevelKey = 2 — позади обычных окон, клики не перехватываем.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey(rawValue: 2)!)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        contentView?.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = contentView?.bounds ?? frame
        contentView?.layer?.addSublayer(layer)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
