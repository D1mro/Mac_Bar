import SwiftUI
import KeyboardShortcuts

/// Окно настроек. Пока горячие клавиши и новое по этапу 5 — остальное на этапе 6.
struct SettingsView: View {
    @AppStorage(WeatherService.cityKey) private var city = ""

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(String(localized: "Скриншот в буфер:"), name: .takeScreenshot)
            KeyboardShortcuts.Recorder(String(localized: "Камера-зеркало:"), name: .cameraMirror)
            Toggle(String(localized: "Вибрации"),
                   isOn: Binding(get: { HapticService.isEnabled() },
                                 set: { HapticService.setIsEnabled($0) }))
            TextField(String(localized: "Город"), text: $city)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
        .onChange(of: city) { _ in WeatherService.shared.update() }
    }
}
