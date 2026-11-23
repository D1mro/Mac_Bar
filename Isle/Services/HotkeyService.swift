import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Имена новые (не "screenshot"), чтобы сохранённая старая ⌃⇧S не перебила новые значения.
    /// Скриншот в буфер. По умолчанию ⌥⇧4.
    static let takeScreenshot = Self("takeScreenshot", initial: .init(.four, modifiers: [.option, .shift]))
    /// Камера-зеркало под островом. По умолчанию ⌥⇧3.
    static let cameraMirror = Self("cameraMirror", initial: .init(.three, modifiers: [.option, .shift]))
}

/// Глобальные горячие клавиши. Меняются в настройках.
@MainActor
enum HotkeyService {
    static func start(island: IslandViewModel, cameraMirror: CameraMirrorController) {
        KeyboardShortcuts.onKeyUp(for: .takeScreenshot) { [weak island] in
            island?.takeScreenshot()
        }
        KeyboardShortcuts.onKeyUp(for: .cameraMirror) { [weak cameraMirror] in
            cameraMirror?.toggle()
        }
    }
}
