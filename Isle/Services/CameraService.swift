import AVFoundation

/// Камера для зеркала (вкладка «Камера» и окошко по ⌥⇧3).
/// Вся работа с AVCaptureSession — на своей последовательной очереди,
/// чтобы не тормозить интерфейс. Считаем, сколько экранов сейчас показывают камеру:
/// она горит, пока есть хотя бы один, и гаснет, когда последний закрылся.
final class CameraService: @unchecked Sendable {
    enum StartResult: Sendable {
        case running
        case denied     // пользователь не дал доступ
        case noCamera   // камеры нет вообще
    }

    static let shared = CameraService()

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.isle.camera")

    // Эти поля трогаем только на `queue`.
    private var users = 0
    private var currentDevice: AVCaptureDevice?

    private init() {
        // Камера отвалилась (iPhone заблокировали, отключили USB-камеру)
        // или сессия упала — переподключаемся к лучшей доступной.
        let center = NotificationCenter.default
        center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil) { [weak self] _ in
            self?.scheduleRestart()
        }
        center.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: nil) { [weak self] _ in
            self?.scheduleRestart()
        }
        center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] _ in
            self?.scheduleRestart()
        }
    }

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

    // MARK: - На очереди камеры

    private func startOnQueue() -> StartResult {
        guard users > 0 else { return .running }   // уже успели закрыть
        guard connectBestDevice() else { return .noCamera }
        if !session.isRunning { session.startRunning() }
        return .running
    }

    private func scheduleRestart() {
        queue.async { self.restartIfNeeded() }
    }

    private func restartIfNeeded() {
        guard users > 0 else { return }
        if session.isRunning { session.stopRunning() }
        if connectBestDevice() { session.startRunning() }
    }

    /// Подключает лучшую камеру, если текущая отвалилась или появилась лучше.
    /// Каждый раз проверяем заново — камера могла смениться, пока зеркало было закрыто.
    private func connectBestDevice() -> Bool {
        guard let best = Self.bestDevice() else { return false }
        if let currentDevice, currentDevice.uniqueID == best.uniqueID, currentDevice.isConnected {
            return true
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        for input in session.inputs { session.removeInput(input) }
        guard let input = try? AVCaptureDeviceInput(device: best), session.canAddInput(input) else {
            currentDevice = nil
            return false
        }
        session.sessionPreset = .high
        session.addInput(input)
        currentDevice = best
        return true
    }

    /// Встроенная камера → внешняя USB → iPhone (Continuity Camera).
    private static func bestDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        let order: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external, .continuityCamera]
        return discovery.devices
            .filter { $0.isConnected && !$0.isSuspended }
            .min { (order.firstIndex(of: $0.deviceType) ?? 9) < (order.firstIndex(of: $1.deviceType) ?? 9) }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}
