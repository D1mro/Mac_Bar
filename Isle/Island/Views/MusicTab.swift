import AppKit
import SwiftUI

/// Плеер в раскрытом острове — по макету из CLAUDE.md («Плеер — макет»).
struct MusicTab: View {
    let model: IslandViewModel
    private var player: NowPlayingService { model.nowPlaying }

    var body: some View {
        if player.hasMedia && model.showsLyrics {
            ZStack(alignment: .topTrailing) {
                LyricsView(player: player, lyrics: .shared)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                lyricsToggle
            }
        } else if player.hasMedia {
            VStack(spacing: 8) {
                header
                ProgressRow(player: player)
                controls
            }
            // Свайп вправо — предыдущий трек, влево — следующий.
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > 50, abs(value.translation.height) < 40 else { return }
                        dx > 0 ? player.previous() : player.next()
                    }
            )
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                Text("Ничего не играет")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Обложка, название, кнопки справа

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            // Клик по обложке — открыть приложение, где играет музыка (или браузер).
            Button { player.openSourceApp() } label: {
                ArtworkView(image: player.artwork, size: 64, cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Открыть плеер"))

            VStack(alignment: .leading, spacing: 2) {
                Text(player.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(player.artist)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            .padding(.top, 6)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 14) {
                    lyricsToggle
                    iconButton("list.bullet") { player.openSourceApp() }
                }
                HStack(spacing: 8) {
                    if let icon = player.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    SoundBars(isPlaying: player.isPlaying, color: player.accent)
                }
            }
            .padding(.top, 4)
        }
    }

    /// Переключатель «плеер ⇄ текст песни».
    private var lyricsToggle: some View {
        iconButton(model.showsLyrics ? "quote.bubble.fill" : "quote.bubble") {
            withAnimation(IslandViewModel.animation) { model.showsLyrics.toggle() }
        }
    }

    // MARK: - Управление

    private var controls: some View {
        ZStack {
            HStack(spacing: 24) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22))
                        .frame(width: 36, height: 34)
                }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .frame(width: 36, height: 34)
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 26))
                        .frame(width: 36, height: 34)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            HStack {
                Spacer()
                OutputDeviceButton(model: model)
            }
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Прогресс

/// Время слева, оставшееся справа, полоса посередине. Полосу можно тянуть — перемотка.
private struct ProgressRow: View {
    let player: NowPlayingService
    /// Позиция пальца во время перетаскивания (0…1).
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(player.duration, 1)
            let fraction = dragFraction ?? min(player.elapsed(at: context.date) / duration, 1)
            let elapsed = fraction * player.duration

            HStack(spacing: 10) {
                timeLabel(Self.format(elapsed))
                    .frame(width: 44, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(player.accent)
                            .frame(width: geometry.size.width * fraction)
                    }
                    .frame(height: 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                            }
                            .onEnded { _ in
                                if let dragFraction { player.seek(to: dragFraction * player.duration) }
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 16)

                timeLabel("−" + Self.format(player.duration - elapsed))
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Обложка

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Устройство вывода

/// Иконка текущего устройства вывода; по клику — меню выбора.
private struct OutputDeviceButton: View {
    let model: IslandViewModel
    private var audio: AudioOutputService { .shared }

    var body: some View {
        Button(action: showMenu) {
            Image(systemName: audio.current?.icon ?? "hifispeaker")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func showMenu() {
        let menu = NSMenu()
        for device in audio.devices {
            let item = ClosureMenuItem(title: device.name) { audio.select(device) }
            item.state = device.id == audio.currentID ? .on : .off
            item.image = NSImage(systemSymbolName: device.icon, accessibilityDescription: nil)
            menu.addItem(item)
        }
        // Пока меню открыто, остров не закрывается от ухода курсора.
        model.withHoverLocked {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
}

/// Пункт меню с замыканием вместо target/action.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) не используется") }

    @objc private func fire() { handler() }
}
