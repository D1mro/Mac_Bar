import AVFoundation

/// Камера для зеркала (вкладка «Камера» и окошко по ⌥⇧5).
/// Вся работа с AVCaptureSession — на своей последовательной очереди,
/// чтобы не тормозить интерфейс. Считаем, сколько экранов сейчас показывают камеру:
/// она горит, пока есть хотя бы один, и гаснет, когда последний закрылся.
final class CameraService: @unchecked Sendable {
    enum StartResult: Sendable {
        case running
        case denied     // пользователь не дал доступ
        case noCamera   // камеры нет (например, крышка ноутбука закрыта)
    }

    static let shared = CameraService()

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.isle.camera")

    // Эти поля трогаем только на `queue`.
    private var isConfigured = false
    private var users = 0

    /// Включить камеру. Возвращает результат, когда превью уже можно показывать.
    func start() async -> StartResult {
        // Сразу ставим в очередь «+1 зритель» — так быстрый stop() после start()
        // гарантированно выключит камеру, даже если запрос доступа ещё не закончился.
        // Каждый start() должен закончиться ровно одним stop().
        queue.async { self.users += 1 }

        guard await Self.requestAccess() else { return .denied }

        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.startOnQueue()) }
        }
    }

    /// «−1 зритель». Последний выключает камеру (зелёная лампочка гаснет).
    func stop() {
        queue.async {
            self.users = max(0, self.users - 1)
            if self.users == 0, self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func startOnQueue() -> StartResult {
        guard users > 0 else { return .running }   // уже успели закрыть

        if !isConfigured {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else { return .noCamera }

            session.beginConfiguration()
            session.sessionPreset = .high
            session.addInput(input)
            session.commitConfiguration()
            isConfigured = true
        }

        if !session.isRunning { session.startRunning() }
        return .running
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
