import AppKit
import CoreGraphics

/// Скриншот в буфер обмена: свой оверлей выбора + системный `screencapture` для снимка.
@MainActor
enum ScreenshotService {
    enum Result {
        case copied        // картинка в буфере
        case cancelled     // нажали Esc или скриншот уже идёт
        case noPermission  // нет доступа к записи экрана
    }

    private static var isRunning = false

    /// Показывает режим выбора (область / окно / весь экран) и копирует снимок в буфер.
    static func captureToClipboard() async -> Result {
        guard !isRunning else { return .cancelled }
        // Без разрешения «Запись экрана» снимок получается пустым.
        guard ensurePermission() else { return .noPermission }

        isRunning = true
        defer { isRunning = false }

        let arguments: [String]
        switch await ScreenshotOverlay.select() {
        case .cancelled:
            return .cancelled
        case .region(let rect):
            let r = rect.integral
            arguments = ["-c", "-R", "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))"]
        case .window(let id):
            arguments = ["-c", "-o", "-l", "\(id)"]   // -o: без тени окна
        }

        // Даём оверлею исчезнуть с экрана, чтобы он не попал в кадр.
        try? await Task.sleep(for: .milliseconds(120))

        // По счётчику буфера понимаем, получился ли снимок.
        let changeCountBefore = NSPasteboard.general.changeCount
        await run(arguments)
        return NSPasteboard.general.changeCount != changeCountBefore ? .copied : .cancelled
    }

    private static func run(_ arguments: [String]) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume()
            }
        }
    }

    /// Есть ли доступ к записи экрана. Если нет — показывает системный запрос
    /// (только в первый раз) и открывает нужный раздел Системных настроек.
    private static func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        if CGRequestScreenCaptureAccess() { return true }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
        return false
    }
}
