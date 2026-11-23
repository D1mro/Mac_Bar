import SwiftUI

@main
struct IsleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Isle", systemImage: "capsule.fill") {
            MenuContent(appDelegate: appDelegate)
        }

        Settings {
            SettingsView()
        }
    }
}

/// Пункты меню в строке меню.
private struct MenuContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(String(localized: "Скриншот в буфер")) {
            appDelegate.island?.model.takeScreenshot()
        }
        Button(String(localized: "Камера-зеркало")) {
            appDelegate.cameraMirror.toggle()
        }
        Button(String(localized: "Настройки…")) {
            // У приложения-агента нет Dock-иконки, поэтому активируем его вручную,
            // иначе окно настроек откроется за другими окнами.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        #if DEBUG
        Divider()
        // Временные пункты для ручной проверки состояний острова.
        Button(String(localized: "Тест: уведомление")) {
            appDelegate.island?.model.show(
                IslandNotification(icon: "doc.on.clipboard", text: String(localized: "Скопировано"))
            )
        }
        #endif

        Divider()
        Button(String(localized: "Выйти")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
