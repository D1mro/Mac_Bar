import AppKit
import AVFoundation
import IOKit.ps

/// Обои: обычная картинка через `NSWorkspace` или «живое» видео на уровне рабочего стола.
@MainActor
final class WallpaperService {
    static let shared = WallpaperService()

    private static let pathKey = "wallpaperPath"
    private var liveWindow: LiveWallpaperWindow?
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    /// Восстановить обои, выбранные в прошлый раз.
    func restore() {
        guard let path = UserDefaults.standard.string(forKey: Self.pathKey), !path.isEmpty else { return }
        apply(url: URL(fileURLWithPath: path))
    }

    /// Диалог выбора: изображение или видео.
    func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .movie]
        panel.message = String(localized: "Выбери изображение или видео для рабочего стола")
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.apply(url: url) }
        }
    }

    private func apply(url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.pathKey)
        let isVideo = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
        if isVideo {
            startLive(url: url)
        } else {
            stopLive()
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }

    // MARK: - Живые обои

    private func startLive(url: URL) {
        stopLive()
        let player = AVPlayer(url: url)
        player.isMuted = true
        let window = LiveWallpaperWindow(player: player)
        window.orderFrontRegardless()
        self.player = player
        self.liveWindow = window

        // Зацикливание.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.player?.seek(to: .zero)
                self?.updatePlayback()
            }
        }
        // Состояние питания проверяем только при активации приложения — без фоновых таймеров.
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePlayback() }
        }
        updatePlayback()
    }

    private func updatePlayback() {
        guard let player else { return }
        if Self.isOnBattery() {
            player.pause()
        } else {
            player.play()
        }
    }

    private func stopLive() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        endObserver = nil
        activeObserver = nil
        player?.pause()
        liveWindow?.close()
        player = nil
        liveWindow = nil
    }

    /// На батарее живые обои ставятся на паузу.
    private static func isOnBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeUnretainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeUnretainedValue() as? [CFTypeRef]
        else { return false }
        for source in sources {
            let details = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? NSDictionary
            if let state = details?[kIOPSPowerSourceStateKey] as? String,
               state == kIOPSBatteryPowerValue {
                return true
            }
        }
        return false
    }
}
