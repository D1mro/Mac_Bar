import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Скриншот области в буфер. По умолчанию ⌃⇧S, меняется в настройках.
    static let screenshot = Self("screenshot", initial: .init(.s, modifiers: [.control, .shift]))
}

/// Глобальные горячие клавиши.
@MainActor
enum HotkeyService {
    static func start(model: IslandViewModel) {
        KeyboardShortcuts.onKeyUp(for: .screenshot) { [weak model] in
            model?.takeScreenshot()
        }
    }
}
