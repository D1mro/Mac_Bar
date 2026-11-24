import AppKit

/// Лёгкая «вибрация» трекпада Force Touch (выключается в настройках).
enum HapticService {
    /// Ключ в UserDefaults; по умолчанию включено (регистрируем в AppDelegate).
    static let isEnabledKey = "hapticsEnabled"

    @MainActor
    static func isEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: isEnabledKey)
    }

    @MainActor
    static func setIsEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: isEnabledKey)
    }

    @MainActor
    static func tap() {
        guard isEnabled() else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
