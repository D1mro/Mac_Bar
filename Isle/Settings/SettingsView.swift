import SwiftUI
import KeyboardShortcuts

/// Окно настроек. Пока только горячая клавиша — остальное на этапе 6.
struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(String(localized: "Скриншот в буфер:"), name: .takeScreenshot)
            KeyboardShortcuts.Recorder(String(localized: "Камера-зеркало:"), name: .cameraMirror)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }
}
