import AppKit
import SwiftUI

/// Что выбрал пользователь в режиме скриншота.
enum ScreenshotSelection {
    /// Прямоугольник. Координаты от левого верхнего угла (как у `screencapture -R`).
    case region(CGRect)
    /// Окно приложения целиком.
    case window(CGWindowID)
    case cancelled
}

/// Окно, которое можно снять кликом.
struct CapturableWindow: Identifiable {
    let id: CGWindowID
    /// Рамка в координатах оверлея (от левого верхнего угла экрана).
    let frame: CGRect
}

/// Прозрачный слой поверх экрана под курсором:
/// протянул — область, кликнул по окну — окно, кнопка «Весь экран», Esc — отмена.
@MainActor
final class ScreenshotOverlay {
    /// Держим оверлей живым, пока пользователь выбирает.
    private static var current: ScreenshotOverlay?

    private let screen: NSScreen
    /// Левый верхний угол экрана в глобальных координатах (y растёт вниз).
    private let origin: CGPoint
    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var continuation: CheckedContinuation<ScreenshotSelection, Never>?

    /// Показать оверлей и дождаться выбора.
    static func select() async -> ScreenshotSelection {
        let mouse = NSEvent.mouseLocation
        guard current == nil,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return .cancelled }

        let overlay = ScreenshotOverlay(screen: screen)
        current = overlay
        return await withCheckedContinuation { overlay.show(continuation: $0) }
    }

    private init(screen: NSScreen) {
        self.screen = screen
        // В AppKit y растёт вверх от низа главного экрана, в screencapture/CGWindow — вниз от верха.
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        origin = CGPoint(x: screen.frame.minX, y: primaryTop - screen.frame.maxY)
    }

    private func show(continuation: CheckedContinuation<ScreenshotSelection, Never>) {
        self.continuation = continuation

        let view = ScreenshotOverlayView(size: screen.frame.size,
                                         windows: visibleWindows()) { [weak self] selection in
            self?.finish(selection)
        }

        let panel = OverlayPanel(contentRect: screen.frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(screen.frame, display: true)
        // Панель без активации: другое приложение остаётся активным,
        // но клавиши (Esc) приходят к нам.
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // 53 = Esc
            MainActor.assumeIsolated { self?.finish(.cancelled) }
            return nil
        }
        NSCursor.crosshair.push()
    }

    private func finish(_ selection: ScreenshotSelection) {
        guard let continuation else { return }
        self.continuation = nil

        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        NSCursor.pop()
        panel?.orderOut(nil)
        panel = nil
        Self.current = nil

        // Переводим область из координат оверлея в глобальные.
        if case .region(let rect) = selection {
            continuation.resume(returning: .region(rect.offsetBy(dx: origin.x, dy: origin.y)))
        } else {
            continuation.resume(returning: selection)
        }
    }

    /// Обычные окна на этом экране, сверху вниз (первое — самое верхнее).
    private func visibleWindows() -> [CapturableWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        let myPID = ProcessInfo.processInfo.processIdentifier
        let screenRect = CGRect(origin: origin, size: screen.frame.size)

        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,              // обычные окна, без Dock и меню
                  (info[kCGWindowOwnerPID as String] as? Int32) != myPID,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 40, bounds.height > 40,
                  bounds.intersects(screenRect)
            else { return nil }
            return CapturableWindow(id: id, frame: bounds.offsetBy(dx: -origin.x, dy: -origin.y))
        }
    }
}

/// Панель без рамки, которая может получать клавиши.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
