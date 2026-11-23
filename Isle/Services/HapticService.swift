import AppKit

/// Лёгкая «вибрация» трекпада Force Touch.
/// Ощущается, только если палец на трекпаде (с мышью её не будет).
/// Тумблер вкл/выкл появится в настройках (этап 6).
enum HapticService {
    @MainActor
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
