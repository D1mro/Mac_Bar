import AppKit
import SwiftUI

/// Прозрачная панель без рамки поверх строки меню, по центру сверху.
/// Размер окна постоянный (с запасом под раскрытый остров),
/// а сам остров рисуется внутри и меняет размер анимацией.
final class IslandWindow: NSPanel {
    static let canvasSize = CGSize(width: 760, height: 260)

    init<Content: View>(rootView: Content) {
        super.init(contentRect: NSRect(origin: .zero, size: Self.canvasSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        // .stationary — окно стоит на месте при свайпе между рабочими столами
        // (с .transient оно «уезжало» вместе со старым столом).
        // В Mission Control такие окна видны — их прячет MissionControlWatcher.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Не попадать на скриншоты и запись экрана — кроме «режима для скриншотов»
        // (пункт в меню: чтобы снять остров для постов/README).
        applySharingMode()
        // Системные фреймворки могут менять UserDefaults в фоне — обрабатываем только
        // на главном потоке, иначе @MainActor-метод упадёт по Swift 6.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applySharingMode() }
        }
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

    static let showInScreenshotsKey = "showInScreenshots"
    private var defaultsObserver: NSObjectProtocol?

    /// «Режим для скриншотов» включён: остров виден на снимках и не сворачивается перед ними.
    static var showsInScreenshots: Bool {
        UserDefaults.standard.bool(forKey: showInScreenshotsKey)
    }

    private func applySharingMode() {
        let show = UserDefaults.standard.bool(forKey: Self.showInScreenshotsKey)
        sharingType = show ? .readOnly : .none
    }

    // Не забираем фокус у других приложений.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Плавно спрятать/показать (для Mission Control).
    func setHiddenAnimated(_ hidden: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hidden ? 0.12 : 0.25
            animator().alphaValue = hidden ? 0 : 1
        }
    }

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
