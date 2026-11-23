import AppKit
import KeyboardShortcuts
import SwiftUI

/// Окошко-зеркало под островом по горячей клавише (⌥⇧3), без раскрытия острова.
/// Закрыть: повторное нажатие, Esc или клик по окошку.
@MainActor
final class CameraMirrorController {
    static let mirrorSize = CGSize(width: 320, height: 180)
    /// Отступ от нижнего края выреза.
    private static let gap: CGFloat = 8
    /// Запас вокруг зеркала под анимацию и обводку.
    private static let margin: CGFloat = 4

    private let state = CameraMirrorState()
    private lazy var panel: NSPanel = makePanel()
    private var hideTask: Task<Void, Never>?
    private var escapeTask: Task<Void, Never>?
    /// Мы сейчас «держим» камеру (сделали start() без парного stop()).
    private var holdsCamera = false

    func toggle() {
        state.isVisible ? hide() : show()
    }

    func show() {
        guard !state.isVisible else { return }
        hideTask?.cancel()
        place()
        panel.orderFrontRegardless()
        withAnimation(IslandViewModel.animation) { state.isVisible = true }

        // Камерой управляем отсюда, а не жизнью SwiftUI-вида:
        // так включение и выключение всегда парные и предсказуемые.
        if !holdsCamera {
            holdsCamera = true
            // status не сбрасываем: превью-слой остаётся тем же, камера просто снова запускается.
            Task { [state] in state.status = await CameraService.shared.start() }
        }
        listenForEscape()
    }

    func hide() {
        guard state.isVisible else { return }
        withAnimation(IslandViewModel.animation) { state.isVisible = false }

        if holdsCamera {
            holdsCamera = false
            CameraService.shared.stop()
        }
        escapeTask?.cancel()
        escapeTask = nil

        // Убираем окно, когда анимация закрытия закончилась.
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self, !self.state.isVisible else { return }
            self.panel.orderOut(nil)
        }
    }

    /// Esc ловим глобально, но только пока зеркало открыто —
    /// клавиша регистрируется при открытии и освобождается при закрытии.
    private func listenForEscape() {
        escapeTask?.cancel()
        escapeTask = Task { [weak self] in
            for await _ in KeyboardShortcuts.events(.keyDown, for: KeyboardShortcuts.Shortcut(.escape)) {
                self?.hide()
                break
            }
        }
    }

    /// По центру экрана с островом, сразу под вырезом.
    private func place() {
        guard let geometry = ScreenGeometry.current() else { return }
        let screen = geometry.screenFrame
        let size = CGSize(width: Self.mirrorSize.width + Self.margin * 2,
                          height: Self.mirrorSize.height + Self.margin * 2)
        let top = screen.maxY - geometry.notchSize.height - Self.gap + Self.margin
        panel.setFrame(NSRect(x: screen.midX - size.width / 2,
                              y: top - size.height,
                              width: size.width,
                              height: size.height),
                       display: true)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        let view = CameraMirrorPanelView(state: state) { [weak self] in self?.hide() }
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }
}

@MainActor
@Observable
final class CameraMirrorState {
    var isVisible = false
    var status: CameraService.StartResult?
}

/// Зеркало живёт всё время (превью не пересоздаётся) —
/// при показе/скрытии меняются только масштаб и прозрачность.
private struct CameraMirrorPanelView: View {
    let state: CameraMirrorState
    let onClose: () -> Void

    var body: some View {
        CameraMirrorContent(status: state.status)
            .frame(width: CameraMirrorController.mirrorSize.width,
                   height: CameraMirrorController.mirrorSize.height)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 1))
            .onTapGesture(perform: onClose)
            .scaleEffect(state.isVisible ? 1 : 0.85, anchor: .top)
            .opacity(state.isVisible ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
