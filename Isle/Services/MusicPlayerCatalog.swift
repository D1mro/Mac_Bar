import AppKit

/// Каталог плееров, в которые можно переключиться через бар.
/// Показываем только установленные (и текущий, если не в списке).
@MainActor
final class MusicPlayerCatalog {
    static let shared = MusicPlayerCatalog()

    struct Player: Identifiable {
        let id = UUID()
        let name: String
        let bundleID: String
    }

    private static let players: [(name: String, bundleID: String)] = [
        ("Яндекс Музыка", "ru.yandex.desktop.music"),
        ("Spotify", "com.spotify.client"),
        ("Apple Music", "com.apple.Music"),
        ("Safari", "com.apple.Safari"),
        ("VLC", "org.videolan.vlc"),
    ]

    /// Список для меню: установленные плееры + текущий, если он не установлен.
    func menuPlayers(currentBundleID: String?) -> [Player] {
        var result = Self.players
            .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
            .map { Player(name: $0.name, bundleID: $0.bundleID) }
        if let currentBundleID,
           !result.contains(where: { $0.bundleID == currentBundleID }),
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: currentBundleID) != nil {
            result.append(Player(name: name(for: currentBundleID), bundleID: currentBundleID))
        }
        return result
    }

    /// Открыть выбранный плеер.
    func open(_ player: Player) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func name(for bundleID: String) -> String {
        Self.players.first { $0.bundleID == bundleID }?.name ?? bundleID
    }
}
