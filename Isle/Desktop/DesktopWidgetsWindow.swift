import AppKit
import CoreGraphics
import SwiftUI

/// Виджеты на рабочем столе: часы, музыка, погода. Перетаскиваются мышью.
enum DesktopWidget: String, CaseIterable {
    case clock, music, weather

    static let enabledKey = "desktopWidgetsEnabled"
    private static let originPrefix = "desktopWidgetOrigin."

    var size: CGSize {
        switch self {
        case .clock: return CGSize(width: 180, height: 62)
        case .music: return CGSize(width: 210, height: 62)
        case .weather: return CGSize(width: 160, height: 62)
        }
    }

    func defaultOrigin(in screen: NSRect) -> CGPoint {
        let margin: CGFloat = 20
        switch self {
        case .clock:
            return CGPoint(x: screen.minX + margin, y: screen.maxY - 100)
        case .music:
            return CGPoint(x: screen.minX + margin, y: screen.maxY - 172)
        case .weather:
            return CGPoint(x: screen.maxX - margin - size.width, y: screen.maxY - 100)
        }
    }

    func savedOrigin(in screen: NSRect) -> CGPoint {
        guard let value = UserDefaults.standard.string(forKey: Self.originPrefix + rawValue),
              !value.isEmpty else { return defaultOrigin(in: screen) }
        return NSPointFromString(value)
    }

    func saveOrigin(_ point: CGPoint) {
        UserDefaults.standard.set(NSStringFromPoint(point), forKey: Self.originPrefix + rawValue)
    }

    @ViewBuilder var view: some View {
        switch self {
        case .clock: ClockWidgetView()
        case .music: MusicWidgetView()
        case .weather: WeatherWidgetView()
        }
    }
}

/// Создаёт и закрывает маленькие панели-виджеты. Они не активируют приложение и не ловят фокус.
@MainActor
final class DesktopWidgetsController {
    private var panels: [DesktopWidget: NSPanel] = [:]
    private var moveObservers: [NSObjectProtocol] = []

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DesktopWidget.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: DesktopWidget.enabledKey)
            if newValue { start() } else { stop() }
        }
    }

    func start() {
        guard panels.isEmpty, let screen = NSScreen.main?.frame else { return }
        for widget in DesktopWidget.allCases {
            let panel = NSPanel(contentRect: NSRect(origin: widget.savedOrigin(in: screen), size: widget.size),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false)
            // kCGDesktopIconWindowLevelKey = 18 — над обоями, но ниже обычных окон.
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(CGWindowLevelKey(rawValue: 18)!)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.isMovable = true       // перетаскивание за любое место виджета
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false

            let host = NSHostingView(rootView: widget.view)
            host.sizingOptions = []
            panel.contentView = host
            panel.orderFrontRegardless()
            panels[widget] = panel

            moveObservers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification, object: panel, queue: .main
            ) { [widget] note in
                guard let window = note.object as? NSWindow else { return }
                MainActor.assumeIsolated { widget.saveOrigin(window.frame.origin) }
            })
        }
    }

    func stop() {
        for observer in moveObservers { NotificationCenter.default.removeObserver(observer) }
        moveObservers.removeAll()
        for panel in panels.values { panel.close() }
        panels.removeAll()
    }
}
