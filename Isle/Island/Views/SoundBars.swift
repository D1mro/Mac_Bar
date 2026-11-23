import SwiftUI

/// Звуковой бар: 5 капсул шириной 3, зазор 2, высота 4…18.
/// Двигается от настоящего звука приложения-источника (AudioVisualizerService).
/// Если звука нет (нет разрешения, macOS < 14.2) — псевдо-анимация из синусов.
/// На паузе бары плавно опускаются до точек.
struct SoundBars: View {
    let isPlaying: Bool
    let color: Color

    private static let speeds: [Double] = [7.1, 9.3, 6.2, 8.4, 10.6]
    private static let phases: [Double] = [0, 1.7, 3.1, 0.9, 2.4]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let levels = isPlaying ? AudioVisualizerService.shared.currentLevels() : nil
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: height(index, time: time, levels: levels))
                }
            }
            .frame(height: 18)
        }
        .animation(.easeOut(duration: 0.35), value: isPlaying)
        // Tap включён, только пока бар на экране.
        .onAppear { AudioVisualizerService.shared.acquire() }
        .onDisappear { AudioVisualizerService.shared.release() }
    }

    private func height(_ index: Int, time: Double, levels: [Float]?) -> CGFloat {
        guard isPlaying else { return 3 }
        if let levels { return 4 + CGFloat(levels[index]) * 14 }
        // Псевдо-анимация: сумма двух синусов со сдвигом фаз.
        let speed = Self.speeds[index]
        let phase = Self.phases[index]
        let wave = (sin(time * speed + phase) + 0.5 * sin(time * speed * 0.53 + phase * 2)) / 1.5
        return 4 + CGFloat((wave + 1) / 2) * 14
    }
}
