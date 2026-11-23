import AppKit

/// Следит, открыт ли Mission Control.
///
/// Публичного API нет, но признак надёжный: в Mission Control у процесса Dock
/// появляется окно на весь экран (слой 20), в обычном режиме его нет.
/// Проверяем 4 раза в секунду — один запрос ~0.4 мс, это < 0.2% CPU.
///
/// Зачем: наши окна стоят в режиме `.stationary` (не уезжают при свайпе
/// между рабочими столами), но такие окна видны в Mission Control — прячем их сами.
@MainActor
final class MissionControlWatcher {
    static let shared = MissionControlWatcher()

    private(set) var isActive = false
    private var handlers: [(Bool) -> Void] = []
    private var timer: Timer?

    /// Подписаться на открытие/закрытие Mission Control.
    func observe(_ handler: @escaping (Bool) -> Void) {
        handlers.append(handler)
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { MissionControlWatcher.shared.check() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func check() {
        let active = Self.dockCoversScreen()
        guard active != isActive else { return }
        isActive = active
        handlers.forEach { $0(active) }
    }

    private static func dockCoversScreen() -> Bool {
        guard let dockPID = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let minWidth = (NSScreen.screens.map(\.frame.width).min() ?? 0) * 0.9
        return list.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == dockPID,
                  (info[kCGWindowLayer as String] as? Int) == 20,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return false }
            return bounds.width >= minWidth
        }
    }
}
