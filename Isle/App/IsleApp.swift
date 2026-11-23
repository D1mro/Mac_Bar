import SwiftUI

@main
struct IsleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Isle", systemImage: "capsule.fill") {
            #if DEBUG
            // Временные пункты для ручной проверки состояний острова.
            Button(String(localized: "Тест: уведомление")) {
                appDelegate.island?.model.show(
                    IslandNotification(icon: "doc.on.clipboard", text: String(localized: "Скопировано"))
                )
            }
            Button(String(localized: "Тест: музыка вкл/выкл")) {
                guard let model = appDelegate.island?.model else { return }
                withAnimation(IslandViewModel.animation) { model.isMusicPlaying.toggle() }
            }
            Divider()
            #endif
            Button(String(localized: "Выйти")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
