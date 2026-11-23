import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var island: IslandController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        island = IslandController()
    }
}
