import AppKit

/// Где находится вырез (notch) и какого он размера.
/// На маках без выреза — «виртуальный» вырез 190×32 по центру сверху.
struct ScreenGeometry: Equatable {
    /// Рамка экрана в координатах AppKit (y растёт вверх).
    let screenFrame: NSRect
    /// Размер выреза (или запасной капсулы).
    let notchSize: CGSize
    let hasNotch: Bool

    static let fallbackNotchSize = CGSize(width: 190, height: 32)

    /// Экран с вырезом, если он есть, иначе главный экран (тот, где строка меню).
    @MainActor
    static func current() -> ScreenGeometry? {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return make(for: notched)
        }
        guard let main = NSScreen.screens.first else { return nil }
        return make(for: main)
    }

    @MainActor
    static func make(for screen: NSScreen) -> ScreenGeometry {
        let top = screen.safeAreaInsets.top
        if top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // Ширина выреза = вся ширина минус свободные области слева и справа от него.
            let width = screen.frame.width - left.width - right.width
            return ScreenGeometry(screenFrame: screen.frame,
                                  notchSize: CGSize(width: width, height: top),
                                  hasNotch: true)
        }
        return ScreenGeometry(screenFrame: screen.frame,
                              notchSize: fallbackNotchSize,
                              hasNotch: false)
    }
}
