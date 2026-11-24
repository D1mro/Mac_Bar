import AppKit

@MainActor

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var island: IslandController?
    let cameraMirror = CameraMirrorController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ВРЕМЕННО, пока делаем приложение: «режим для скриншотов» включён по умолчанию,
        // чтобы остров можно было снимать. Выключается в меню; потом убрать эту строку.
        UserDefaults.standard.register(defaults: [IslandWindow.showInScreenshotsKey: true])
        NowPlayingService.shared.start()
        island = IslandController()
        if let model = island?.model {
            HotkeyService.start(island: model, cameraMirror: cameraMirror)
        }
        // Этап 5: погода. (PowerService убран — стал ответственен за потерю фокуса.)
        UserDefaults.standard.register(defaults: [HapticService.isEnabledKey: true])
        WeatherService.shared.update()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingService.shared.stop()
    }
}
