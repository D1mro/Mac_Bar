import SwiftUI
import KeyboardShortcuts

/// Окно настроек. Пока только горячая клавиша — остальное на этапе 6.
struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(String(localized: "Скриншот в буфер:"), name: .screenshot)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }
}
