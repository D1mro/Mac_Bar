import AppKit
import SwiftUI

/// Прозрачная панель без рамки поверх строки меню, по центру сверху.
/// Размер окна постоянный (с запасом под раскрытый остров),
/// а сам остров рисуется внутри и меняет размер анимацией.
final class IslandWindow: NSPanel {
    static let canvasSize = CGSize(width: 640, height: 260)

    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.canvasSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        // По умолчанию клики проходят насквозь — включаем их, только когда курсор над островом.
        ignoresMouseEvents = true

        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []   // окно не должно менять размер вслед за SwiftUI
        contentView = host
    }

    // Не забираем фокус у других приложений.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Поставить окно по центру верхнего края экрана.
    func place(on geometry: ScreenGeometry) {
        let screen = geometry.screenFrame
        let size = Self.canvasSize
        let frame = NSRect(x: screen.midX - size.width / 2,
                           y: screen.maxY - size.height,
                           width: size.width,
                           height: size.height)
        setFrame(frame, display: true)
    }
}
