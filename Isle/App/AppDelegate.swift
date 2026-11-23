import AppKit

@MainActor

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var island: IslandController?
    let cameraMirror = CameraMirrorController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NowPlayingService.shared.start()
        island = IslandController()
        if let model = island?.model {
            HotkeyService.start(island: model, cameraMirror: cameraMirror)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NowPlayingService.shared.stop()
    }
}
