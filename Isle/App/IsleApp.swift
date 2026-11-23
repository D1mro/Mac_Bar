import SwiftUI

@main
struct IsleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Isle", systemImage: "capsule.fill") {
            Button(String(localized: "Выйти")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
