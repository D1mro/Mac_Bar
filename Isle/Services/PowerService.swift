import CoreFoundation
import Foundation
import IOKit.ps

/// Батарея: процент заряда и уведомление при подключении кабеля (в компактном виде).
@MainActor
final class PowerService {
    static let shared = PowerService()

    /// Последний известный процент заряда (0…100).
    private(set) var percent: Int?

    /// Вызывается при изменении состояния источников питания.
    var onCharging: ((Int) -> Void)?

    private var isCharging = false
    private var runLoopSource: CFRunLoopSource?

    func start() {
        update()
        // IOKit-события: вместо 5-секундного опроса — уведомление при изменении питания.
        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            MainActor.assumeIsolated { PowerService.shared.powerSourceChanged() }
        }, nil)?.takeUnretainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }
    }

    private func powerSourceChanged() {
        update()
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
