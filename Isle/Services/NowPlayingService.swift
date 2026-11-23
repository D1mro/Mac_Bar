import AppKit
import SwiftUI

/// «Что сейчас играет» в любом плеере из Пункта управления → «Исполняется».
/// Основной источник — mediaremote-adapter, запасной — AppleScript (Spotify, Музыка).
@MainActor
@Observable
final class NowPlayingService {
    static let shared = NowPlayingService()

    private(set) var title = ""
    private(set) var artist = ""
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var artwork: NSImage?
    /// Приложение-источник (для браузера — сам браузер, а не его GPU-процесс).
    private(set) var bundleID: String?
    private(set) var appIcon: NSImage?
    private(set) var accent: Color = Color(nsColor: ArtworkPalette.brandColor(for: nil))

    /// Позиция в момент `timestamp`. Текущая считается в `elapsed(at:)`.
    private var elapsedAtTimestamp: TimeInterval = 0
    private var timestamp = Date()

    var hasMedia: Bool { !title.isEmpty }

    /// Вызывается, когда сменился трек (название или исполнитель).
    @ObservationIgnored var onTrackChange: (() -> Void)?

    // Источники
    @ObservationIgnored private let adapter = MediaRemoteAdapter()
    @ObservationIgnored private var usesFallback = false
    @ObservationIgnored private var fallbackTask: Task<Void, Never>?
    /// Накопленное состояние адаптера (он присылает только изменения).
    @ObservationIgnored private var info: [String: Any] = [:]
    @ObservationIgnored private var artworkBase64: String?

    // MARK: - Запуск

    func start() {
        guard let adapter else {
            startFallback()
            return
        }
        adapter.startStream(
            onLine: { line in
                Task { @MainActor in NowPlayingService.shared.handle(line) }
            },
            onExit: { status in
                Task { @MainActor in NowPlayingService.shared.adapterExited(status) }
            }
        )
    }

    func stop() {
        adapter?.stopStream()
        fallbackTask?.cancel()
    }

    private func adapterExited(_ status: Int32) {
        if status == 0 || status == 15 {
            // Вышел штатно (например, после сна) — просто перезапускаем.
            Task {
                try? await Task.sleep(for: .seconds(2))
                start()
            }
        } else {
            // Адаптер сломан (обновление macOS?) — переходим на AppleScript.
            startFallback()
        }
    }

    // MARK: - Текущая позиция

    func elapsed(at date: Date = .now) -> TimeInterval {
        var value = elapsedAtTimestamp
        if isPlaying { value += date.timeIntervalSince(timestamp) }
        if duration > 0 { value = min(value, duration) }
        return max(0, value)
    }

    // MARK: - Управление

    func togglePlayPause() {
        if usesFallback {
            if let bundleID { AppleScriptPlayer.playPause(bundleID) }
        } else {
            adapter?.run(["send", "2"])
        }
    }

    func next() {
        if usesFallback {
            if let bundleID { AppleScriptPlayer.next(bundleID) }
        } else {
            adapter?.run(["send", "4"])
        }
    }

    func previous() {
        if usesFallback {
            if let bundleID { AppleScriptPlayer.previous(bundleID) }
        } else {
            adapter?.run(["send", "5"])
        }
    }

    func seek(to seconds: TimeInterval) {
        let seconds = max(0, min(seconds, duration))
        if usesFallback {
            if let bundleID { AppleScriptPlayer.seek(bundleID, to: seconds) }
        } else {
            adapter?.run(["seek", String(Int(seconds * 1_000_000))])
        }
        // Сразу двигаем прогресс, не дожидаясь ответа плеера.
        elapsedAtTimestamp = seconds
        timestamp = .now
    }

    /// Открыть приложение, где играет музыка (для видео в браузере — браузер).
    /// Очереди в системном API нет, поэтому кнопка «очередь» делает то же самое.
    func openSourceApp() {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Адаптер

    private func handle(_ line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = object["payload"] as? [String: Any]
        else { return }

        if (object["diff"] as? Bool) == true {
            for (key, value) in payload {
                if value is NSNull { info.removeValue(forKey: key) } else { info[key] = value }
            }
        } else {
            info = payload
        }
        applyAdapterInfo()
    }

    private func applyAdapterInfo() {
        let bundle = (info["parentApplicationBundleIdentifier"] as? String)
            ?? (info["bundleIdentifier"] as? String)
        let timestampMicros = info["timestampEpochMicros"] as? Double

        update(title: info["title"] as? String ?? "",
               artist: info["artist"] as? String ?? "",
               duration: (info["durationMicros"] as? Double ?? 0) / 1_000_000,
               elapsed: (info["elapsedTimeMicros"] as? Double ?? 0) / 1_000_000,
               timestamp: timestampMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? .now,
               isPlaying: info["playing"] as? Bool ?? false,
               bundleID: bundle)

        // Обложку декодируем, только когда она поменялась.
        let base64 = info["artworkData"] as? String
        if base64 != artworkBase64 {
            artworkBase64 = base64
            let image = base64
                .flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
                .flatMap(NSImage.init(data:))
            setArtwork(image)
        }
    }

    // MARK: - Запасной вариант (AppleScript)

    private func startFallback() {
        guard !usesFallback else { return }
        usesFallback = true
        fallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                let snapshot = await AppleScriptPlayer.poll()
                guard let self else { return }
                self.update(title: snapshot?.title ?? "",
                            artist: snapshot?.artist ?? "",
                            duration: snapshot?.duration ?? 0,
                            elapsed: snapshot?.position ?? 0,
                            timestamp: .now,
                            isPlaying: snapshot?.isPlaying ?? false,
                            bundleID: snapshot?.bundleID)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Общее

    private func update(title: String, artist: String, duration: TimeInterval,
                        elapsed: TimeInterval, timestamp: Date,
                        isPlaying: Bool, bundleID: String?) {
        let trackChanged = title != self.title || artist != self.artist
        withAnimation(IslandViewModel.animation) {
            self.title = title
            self.isPlaying = isPlaying && !title.isEmpty
        }
        self.artist = artist
        self.duration = duration
        self.elapsedAtTimestamp = elapsed
        self.timestamp = timestamp

        if bundleID != self.bundleID {
            self.bundleID = bundleID
            appIcon = bundleID
                .flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
            if artwork == nil { updateAccent() }
        }

        if trackChanged { onTrackChange?() }
    }

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        updateAccent()
    }

    private func updateAccent() {
        let color = artwork.flatMap(ArtworkPalette.accentColor(of:))
            ?? ArtworkPalette.brandColor(for: bundleID)
        withAnimation(.easeInOut(duration: 0.6)) {
            accent = Color(nsColor: color)
        }
    }
}
