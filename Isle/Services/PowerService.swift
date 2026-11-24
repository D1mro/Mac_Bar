import Foundation
import IOKit.ps

/// Батарея: процент заряда и уведомление при подключении кабеля (в компактном виде).
@MainActor
final class PowerService {
    static let shared = PowerService()

    private var timer: Timer?
    private var isCharging = false

    /// Последний известный процент заряда (0…100).
    private(set) var percent: Int?

    /// Вызывается один раз в момент начала зарядки кабелем.
    var onCharging: ((Int) -> Void)?

    func start() {
        update()
        // Опрашиваем процент каждые 5 сек — проще, чем IOPSNotificationCreateRunLoopSource.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }

    private func update() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeUnretainedValue() else { return }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeUnretainedValue() as? [CFTypeRef] else { return }
        var nextPercent: Int?
        var nextCharging = false
        for source in sources {
            let raw = IOPSGetPowerSourceDescription(blob, source)
            let details = raw?.takeUnretainedValue() as? NSDictionary
            let isCharging = details?[kIOPSIsChargingKey as String] as? Bool
            guard let details, isCharging == true else { continue }
            nextCharging = true
            let current = details[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = details[kIOPSMaxCapacityKey as String] as? Int ?? 0
            if max > 0 { nextPercent = Int((Double(current) / Double(max)) * 100) }
        }
        percent = nextPercent
        if !isCharging, nextCharging, let percent {
            onCharging?(percent)
        }
        isCharging = nextCharging
    }
}
