import AppKit

@MainActor

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var island: IslandController?
    let cameraMirror = CameraMirrorController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        island = IslandController()
        if let model = island?.model {
            HotkeyService.start(island: model, cameraMirror: cameraMirror)
        }
    }
}
