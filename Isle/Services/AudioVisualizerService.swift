import Accelerate
import CoreAudio
import Foundation
import os

/// Живой звуковой бар: настоящий звук приложения-источника → 5 полос 0…1.
///
/// Как это работает (macOS 14.2+):
/// процессы-источники → `CATapDescription` → process tap → приватный aggregate device →
/// IOProc получает сэмплы → FFT (Accelerate) → 5 полос → сглаживание.
/// Tap работает, только пока бар виден и музыка играет.
/// Нет разрешения или старая macOS — `currentLevels()` вернёт nil, и бар покажет псевдо-анимацию.
final class AudioVisualizerService: @unchecked Sendable {
    static let shared = AudioVisualizerService()

    /// Управление tap — на своей очереди (создание tap занимает до ~100 мс).
    private let queue = DispatchQueue(label: "dev.isle.visualizer")
    /// Сэмплы приходят сюда.
    private let ioQueue = DispatchQueue(label: "dev.isle.visualizer.io", qos: .userInteractive)

    /// Последние уровни для интерфейса (пишет ioQueue, читает main 60 раз в секунду).
    private let levels = OSAllocatedUnfairLock(initialState: Levels())

    private struct Levels {
        var bands = [Float](repeating: 0, count: 5)
        var lastSignal: Date = .distantPast
    }

    // Состояние ниже трогаем только на `queue`.
    private var viewers = 0
    private var isPlaying = false
    private var sourcePID: pid_t?
    private var sourceBundleIDs: [String] = []
    private var running: RunningTap?

    private init() {
        // Сменилось устройство вывода — aggregate device надо пересобрать.
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue) { [weak self] _, _ in
            self?.restart()
        }
    }

    // MARK: - API

    /// Уровни 5 полос или nil, если настоящего звука нет последние 2 сек.
    func currentLevels() -> [Float]? {
        levels.withLock { state in
            Date().timeIntervalSince(state.lastSignal) < 2 ? state.bands : nil
        }
    }

    /// Бар появился на экране. Каждый `acquire()` — ровно один `release()`.
    func acquire() {
        queue.async { self.viewers += 1; self.reconcile() }
    }

    func release() {
        queue.async { self.viewers = max(0, self.viewers - 1); self.reconcile() }
    }

    /// Что играет и в каком процессе (вызывает NowPlayingService).
    func update(isPlaying: Bool, pid: pid_t?, bundleIDs: [String]) {
        queue.async {
            self.isPlaying = isPlaying
            self.sourcePID = pid
            self.sourceBundleIDs = bundleIDs
            self.reconcile()
        }
    }

    // MARK: - Включить / выключить tap

    private func restart() {
        stopTap()
        reconcile()
    }

    private func reconcile() {
        let hasSource = sourcePID != nil || !sourceBundleIDs.isEmpty
        guard viewers > 0, isPlaying, hasSource else {
            stopTap()
            return
        }
        let key = "\(sourcePID ?? 0)|\(sourceBundleIDs.joined(separator: ","))"
        if running?.key == key { return }
        stopTap()
        if #available(macOS 14.2, *) {
            running = startTap(key: key)
        }
    }

    private func stopTap() {
        guard let running else { return }
        AudioDeviceStop(running.aggregateID, running.procID)
        AudioDeviceDestroyIOProcID(running.aggregateID, running.procID)
        AudioHardwareDestroyAggregateDevice(running.aggregateID)
        if #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(running.tapID)
        }
        self.running = nil
        levels.withLock { $0 = Levels() }
    }

    @available(macOS 14.2, *)
    private func startTap(key: String) -> RunningTap? {
        // 1. Аудио-процессы источника. У браузера звук идёт из вспомогательных
        //    процессов (WebKit.GPU, Chrome Helper) — берём их все.
        let processes = Self.processObjects(pid: sourcePID, bundleIDs: sourceBundleIDs)
        guard !processes.isEmpty else { return nil }

        // 2. Process tap: стерео-микс этих процессов, звук у пользователя не глушим.
        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        description.name = "Isle"
        var tapID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr else { return nil }

        // 3. Приватный aggregate device: текущий выход (как часы) + наш tap.
        guard let outputUID = Self.defaultOutputUID() else {
            AudioHardwareDestroyProcessTap(tapID)
            return nil
        }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Isle Visualizer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID) == noErr else {
            AudioHardwareDestroyProcessTap(tapID)
            return nil
        }

        // 4. IOProc: сэмплы → анализатор спектра.
        let analyzer = SpectrumAnalyzer(sampleRate: Self.sampleRate(of: tapID))
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, ioQueue) { [weak self] _, input, _, _, _ in
            guard let self, let bands = analyzer.process(input) else { return }
            self.levels.withLock { state in
                state.bands = bands.levels
                if bands.hasSignal { state.lastSignal = Date() }
            }
        }
        guard status == noErr, let procID, AudioDeviceStart(aggregateID, procID) == noErr else {
            if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            AudioHardwareDestroyProcessTap(tapID)
            return nil
        }
        return RunningTap(key: key, tapID: tapID, aggregateID: aggregateID, procID: procID)
    }

    private struct RunningTap {
        let key: String
        let tapID: AudioObjectID
        let aggregateID: AudioObjectID
        let procID: AudioDeviceIOProcID
    }

    // MARK: - Core Audio: поиск процессов и устройств

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    /// Аудио-объекты процессов, чей pid совпадает или bundle id начинается с bundle id источника.
    @available(macOS 14.2, *)
    private static func processObjects(pid: pid_t?, bundleIDs: [String]) -> [AudioObjectID] {
        var address = address(kAudioHardwarePropertyProcessObjectList)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }

        return objects.filter { object in
            if let pid, processPID(object) == pid { return true }
            guard let bundle = processBundleID(object) else { return false }
            return bundleIDs.contains { bundle == $0 || bundle.hasPrefix($0 + ".") }
        }
    }

    private static func processPID(_ object: AudioObjectID) -> pid_t? {
        var address = address(kAudioProcessPropertyPID)
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &pid) == noErr ? pid : nil
    }

    private static func processBundleID(_ object: AudioObjectID) -> String? {
        var address = address(kAudioProcessPropertyBundleID)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func defaultOutputUID() -> String? {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { return nil }

        var uidAddress = self.address(kAudioDevicePropertyDeviceUID)
        var uid: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uid) == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }

    @available(macOS 14.2, *)
    private static func sampleRate(of tap: AudioObjectID) -> Double {
        var address = address(kAudioTapPropertyFormat)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format) == noErr,
              format.mSampleRate > 0
        else { return 48_000 }
        return format.mSampleRate
    }
}

// MARK: - Анализ спектра

/// Копит моно-сэмплы по 1024, делает FFT и раскладывает по 5 полосам.
/// Используется только на ioQueue.
private final class SpectrumAnalyzer: @unchecked Sendable {
    struct Result {
        let levels: [Float]
        let hasSignal: Bool
    }

    private static let size = 1024
    private static let log2Size: vDSP_Length = 10
    /// Полосы в герцах: бас, низ-середина, середина, верх-середина, верх.
    private static let bands: [(Float, Float)] = [(60, 250), (250, 500), (500, 2000), (2000, 4000), (4000, 12000)]

    private let binWidth: Float
    private let setup: FFTSetup
    private let window: [Float]
    private var samples: [Float] = []
    private var real = [Float](repeating: 0, count: size / 2)
    private var imag = [Float](repeating: 0, count: size / 2)
    private var magnitudes = [Float](repeating: 0, count: size / 2)

    /// Громкость «потолка» каждой полосы — медленно опускается, чтобы бары
    /// подстраивались под общую громкость трека.
    private var peaks = [Float](repeating: 0.003, count: 5)
    private var smoothed = [Float](repeating: 0, count: 5)

    init(sampleRate: Double) {
        binWidth = Float(sampleRate) / Float(Self.size)
        setup = vDSP_create_fftsetup(Self.log2Size, FFTRadix(kFFTRadix2))!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized,
                             count: Self.size, isHalfWindow: false)
        samples.reserveCapacity(Self.size * 2)
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Новые сэмплы. Возвращает уровни, когда накопилось на очередной FFT.
    func process(_ input: UnsafePointer<AudioBufferList>) -> Result? {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let buffer = buffers.first, let data = buffer.mData else { return nil }

        // Сводим в моно (данные — Float32, обычно стерео вперемешку).
        let channels = max(Int(buffer.mNumberChannels), 1)
        let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let floats = data.assumingMemoryBound(to: Float.self)
        for frame in stride(from: 0, to: count - channels + 1, by: channels) {
            var sum: Float = 0
            for channel in 0..<channels { sum += floats[frame + channel] }
            samples.append(sum / Float(channels))
        }

        guard samples.count >= Self.size else { return nil }
        let frame = Array(samples.prefix(Self.size))
        samples.removeFirst(Self.size)
        return analyze(frame)
    }

    private func analyze(_ frame: [Float]) -> Result {
        let hasSignal = (vDSP.maximumMagnitude(frame)) > 1e-5
        let windowed = vDSP.multiply(frame, window)

        // FFT вещественного сигнала: упаковка в комплексный вид → zrip → модули.
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { samplesPtr in
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.size / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(Self.size / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, Self.log2Size, FFTDirection(FFT_FORWARD))
                magnitudes.withUnsafeMutableBufferPointer { magnitudesPtr in
                    vDSP_zvabs(&split, 1, magnitudesPtr.baseAddress!, 1, vDSP_Length(Self.size / 2))
                }
            }
        }

        var levels = [Float](repeating: 0, count: 5)
        for (index, band) in Self.bands.enumerated() {
            let low = max(Int(band.0 / binWidth), 1)
            let high = min(Int(band.1 / binWidth), Self.size / 2 - 1)
            guard high >= low else { continue }
            let energy = magnitudes[low...high].reduce(0, +) / Float(high - low + 1) / Float(Self.size)

            // Нормализация к «потолку» полосы + корень, чтобы тихое тоже было видно.
            peaks[index] = max(peaks[index] * 0.995, energy, 0.003)
            let target = min(sqrt(energy / peaks[index]), 1)

            // Подъём быстрый, спад медленный — бары «прыгают», а не дрожат.
            let factor: Float = target > smoothed[index] ? 0.6 : 0.15
            smoothed[index] += (target - smoothed[index]) * factor
            levels[index] = smoothed[index]
        }
        return Result(levels: levels, hasSignal: hasSignal)
    }
}
