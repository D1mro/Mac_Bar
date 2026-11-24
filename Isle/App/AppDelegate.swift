import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var island: IslandController?
    let cameraMirror = CameraMirrorController()
    let desktopWidgets = DesktopWidgetsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ВРЕМЕННО, пока делаем приложение: «режим для скриншотов» включён по умолчанию.
        UserDefaults.standard.register(defaults: [IslandWindow.showInScreenshotsKey: true,
                                                 HapticService.isEnabledKey: true,
                                                 // Без города виджет погоды пустой.
                                                 WeatherService.cityKey: "Москва",
                                                 DesktopWidget.enabledKey: true])

        NowPlayingService.shared.start()
        island = IslandController()
        if let model = island?.model {
            HotkeyService.start(island: model, cameraMirror: cameraMirror)
        }
        WeatherService.shared.update()

        // Этап 8: рабочий стол.
        WallpaperService.shared.restore()
        if desktopWidgets.isEnabled { desktopWidgets.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingService.shared.stop()
    }
}
