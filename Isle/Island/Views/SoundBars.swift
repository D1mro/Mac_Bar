import SwiftUI

/// Звуковой бар: 5 капсул шириной 3, зазор 2, высота 4…18.
/// Пока это псевдо-анимация (синусы со сдвигом фаз); настоящий звук — этап 4.5.
/// На паузе бары плавно опускаются до точек.
struct SoundBars: View {
    let isPlaying: Bool
    let color: Color

    private static let speeds: [Double] = [7.1, 9.3, 6.2, 8.4, 10.6]
    private static let phases: [Double] = [0, 1.7, 3.1, 0.9, 2.4]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: isPlaying ? height(index, time) : 3)
                }
            }
            .frame(height: 18)
        }
        .animation(.easeOut(duration: 0.35), value: isPlaying)
    }

    private func height(_ index: Int, _ time: Double) -> CGFloat {
        let speed = Self.speeds[index]
        let phase = Self.phases[index]
        // Сумма двух синусов — движение менее «механическое».
        let wave = (sin(time * speed + phase) + 0.5 * sin(time * speed * 0.53 + phase * 2)) / 1.5
        return 4 + CGFloat((wave + 1) / 2) * 14
    }
}
