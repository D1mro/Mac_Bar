import AppKit

/// Запасной способ, если mediaremote-adapter перестал работать:
/// спрашиваем Spotify и Музыку через AppleScript (без обложки).
enum AppleScriptPlayer {
    struct Snapshot: Sendable {
        let bundleID: String
        let title: String
        let artist: String
        let duration: TimeInterval
        let position: TimeInterval
        let isPlaying: Bool
    }

    private static let spotify = "com.spotify.client"
    private static let music = "com.apple.Music"

    /// Что играет сейчас. Играющий плеер важнее стоящего на паузе.
    static func poll() async -> Snapshot? {
        await Task.detached(priority: .utility) {
            let snapshots = [spotify, music].compactMap(snapshot(for:))
            return snapshots.first(where: \.isPlaying) ?? snapshots.first
        }.value
    }

    static func playPause(_ bundleID: String) { send("playpause", to: bundleID) }
    static func next(_ bundleID: String) { send("next track", to: bundleID) }
    static func previous(_ bundleID: String) { send("previous track", to: bundleID) }
    static func seek(_ bundleID: String, to seconds: TimeInterval) {
        send("set player position to \(seconds)", to: bundleID)
    }

    // MARK: - Внутреннее

    private static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private static func snapshot(for bundleID: String) -> Snapshot? {
        // Не запускаем плеер, если он закрыт.
        guard isRunning(bundleID) else { return nil }
        let source = """
        tell application id "\(bundleID)"
            if player state is stopped then return {}
            set t to current track
            return {name of t, artist of t, duration of t, player position, (player state is playing)}
        end tell
        """
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(nil),
              result.numberOfItems == 5
        else { return nil }

        var duration = result.atIndex(3)?.doubleValue ?? 0
        if bundleID == spotify { duration /= 1000 }   // Spotify отдаёт миллисекунды
        return Snapshot(bundleID: bundleID,
                        title: result.atIndex(1)?.stringValue ?? "",
                        artist: result.atIndex(2)?.stringValue ?? "",
                        duration: duration,
                        position: result.atIndex(4)?.doubleValue ?? 0,
                        isPlaying: result.atIndex(5)?.booleanValue ?? false)
    }

    private static func send(_ command: String, to bundleID: String) {
        guard isRunning(bundleID) else { return }
        let source = "tell application id \"\(bundleID)\" to \(command)"
        Task.detached(priority: .userInitiated) {
            _ = NSAppleScript(source: source)?.executeAndReturnError(nil)
        }
    }
}
