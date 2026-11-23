import SwiftUI
import Observation

/// Вкладки раскрытого острова.
enum IslandTab: CaseIterable, Identifiable {
    case music, camera, tools

    var id: Self { self }

    var title: String {
        switch self {
        case .music: String(localized: "Музыка")
        case .camera: String(localized: "Камера")
        case .tools: String(localized: "Инструменты")
        }
    }

    var icon: String {
        switch self {
        case .music: "music.note"
        case .camera: "camera.fill"
        case .tools: "wrench.and.screwdriver.fill"
        }
    }
}

/// Короткое уведомление в компактном виде: «Скопировано», «Зарядка 82%».
struct IslandNotification: Equatable {
    let icon: String
    let text: String
}

enum CompactContent: Equatable {
    /// Сменился трек: обложка + название слева, исполнитель справа (3 сек).
    case track
    case notification(IslandNotification)
}

/// Состояния острова. Приоритет: expanded > notification > track > idle.
enum IslandState: Equatable {
    case idle
    case compact(CompactContent)
    case expanded
}

@MainActor
@Observable
final class IslandViewModel {
    static let animation = Animation.spring(response: 0.42, dampingFraction: 0.8)
    static let earRadius: CGFloat = 6

    var geometry: ScreenGeometry
    var selectedTab: IslandTab = .music
    /// В плеере показан текст песни вместо управления.
    var showsLyrics = false
    let nowPlaying: NowPlayingService

    // Входные сигналы — из них state собирается сам.
    private(set) var isExpanded = false
    private(set) var notification: IslandNotification?
    private(set) var isAnnouncingTrack = false

    init(geometry: ScreenGeometry, nowPlaying: NowPlayingService = .shared) {
        self.geometry = geometry
        self.nowPlaying = nowPlaying
        nowPlaying.onTrackChange = { [weak self] in self?.trackChanged() }
    }

    var state: IslandState {
        if isExpanded { return .expanded }
        if let notification { return .compact(.notification(notification)) }
        if isAnnouncingTrack { return .compact(.track) }
        return .idle
    }

    /// Размер «тела» острова (без ушей) для текущего состояния.
    var size: CGSize {
        let notch = geometry.notchSize
        switch state {
        case .idle: return notch
        case .compact(.notification): return CGSize(width: notch.width + 120, height: notch.height)
        case .compact(.track): return CGSize(width: notch.width + 300, height: notch.height)
        case .expanded: return CGSize(width: 440, height: 190)
        }
    }

    var bottomRadius: CGFloat {
        state == .expanded ? 30 : 10
    }

    // MARK: - Наведение курсора

    private var isHovering = false
    private var hoverTask: Task<Void, Never>?

    /// Раскрываемся через 0.05 сек после наведения, закрываемся через 0.3 сек после ухода.
    func setHovering(_ hovering: Bool) {
        // Пока идёт скриншот или открыто меню, наведение игнорируем.
        guard !isCapturing, !isHoverLocked, hovering != isHovering else { return }
        isHovering = hovering
        hoverTask?.cancel()
        let delay: Duration = hovering ? .milliseconds(50) : .milliseconds(300)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            if hovering && !self.isExpanded {
                HapticService.tap()
            }
            withAnimation(Self.animation) { self.isExpanded = hovering }
        }
    }

    private var isHoverLocked = false

    /// Выполнить действие (например, показать меню), не закрывая остров от ухода курсора.
    /// После него остров снова реагирует на курсор при следующем движении мыши.
    func withHoverLocked(_ action: () -> Void) {
        isHoverLocked = true
        action()
        isHoverLocked = false
    }

    /// Сразу свернуть остров (например, перед скриншотом, чтобы не мешал).
    func collapse() {
        hoverTask?.cancel()
        isHovering = false
        withAnimation(Self.animation) { isExpanded = false }
    }

    // MARK: - Действия

    /// Скриншот области в буфер → «Скопировано» + хаптик.
    private var isCapturing = false

    func takeScreenshot() {
        guard !isCapturing else { return }
        collapse()
        isCapturing = true
        Task {
            defer { isCapturing = false }
            switch await ScreenshotService.captureToClipboard() {
            case .copied:
                show(IslandNotification(icon: "doc.on.clipboard", text: String(localized: "Скопировано")))
                HapticService.tap()
            case .noPermission:
                show(IslandNotification(icon: "lock.fill", text: String(localized: "Нужен доступ")))
            case .cancelled:
                break
            }
        }
    }

    // MARK: - Смена трека

    private var trackTask: Task<Void, Never>?

    private func trackChanged() {
        LyricsService.shared.load(title: nowPlaying.title,
                                  artist: nowPlaying.artist,
                                  duration: nowPlaying.duration)
        guard nowPlaying.isPlaying, nowPlaying.hasMedia else { return }

        // Показываем новый трек в компактном виде на 3 сек.
        trackTask?.cancel()
        withAnimation(Self.animation) { isAnnouncingTrack = true }
        trackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Self.animation) { self.isAnnouncingTrack = false }
        }
    }

    // MARK: - Уведомления

    private var notificationTask: Task<Void, Never>?

    /// Показать уведомление в компактном виде на 1.5 сек.
    func show(_ newNotification: IslandNotification) {
        notificationTask?.cancel()
        withAnimation(Self.animation) { notification = newNotification }
        notificationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Self.animation) { self.notification = nil }
        }
    }
}
