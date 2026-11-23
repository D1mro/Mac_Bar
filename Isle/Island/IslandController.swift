import AppKit
import SwiftUI

/// Связывает окно, модель и мышь:
/// следит за курсором, включает/выключает клики по окну и
/// переставляет остров при смене мониторов.
@MainActor
final class IslandController {
    let model: IslandViewModel
    private let window: IslandWindow
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?

    init?() {
        guard let geometry = ScreenGeometry.current() else { return nil }
        model = IslandViewModel(geometry: geometry)
        window = IslandWindow(rootView: IslandView(model: model))
        window.place(on: geometry)
        window.orderFrontRegardless()
        startMouseTracking()
        observeScreenChanges()
        HotkeyService.start(model: model)
    }

    // MARK: - Мышь

    private func startMouseTracking() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        // Глобальный монитор — когда курсор над другими приложениями,
        // локальный — когда над нашим окном. Разрешений не требует.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }
    }

    private func mouseMoved() {
        // В свёрнутом виде зона чуть больше острова — чтобы легче попасть курсором.
        let slack: CGFloat = model.state == .expanded ? 0 : 6
        let inside = islandRect.insetBy(dx: -slack, dy: -slack).contains(NSEvent.mouseLocation)
        // Там, где острова нет, клики уходят строке меню и другим окнам.
        window.ignoresMouseEvents = !inside
        model.setHovering(inside)
    }

    /// Прямоугольник острова в координатах экрана (y растёт вверх).
    private var islandRect: NSRect {
        let screen = model.geometry.screenFrame
        let size = model.size
        let width = size.width + IslandViewModel.earRadius * 2
        return NSRect(x: screen.midX - width / 2,
                      y: screen.maxY - size.height,
                      width: width,
                      height: size.height)
    }

    // MARK: - Мониторы

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildForScreens() }
        }
    }

    private func rebuildForScreens() {
        guard let geometry = ScreenGeometry.current() else { return }
        model.geometry = geometry
        window.place(on: geometry)
    }
}
