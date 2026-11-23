import SwiftUI

/// Форма острова: плоский верх, скруглённый низ и маленькие
/// вогнутые «уши» сверху по бокам, чтобы остров плавно вытекал из рамки экрана.
///
///  ‾‾\________/‾‾   ← уши (earRadius)
///     |      |
///     \______/      ← нижние углы (bottomRadius)
///
/// Ширина rect = ширина тела + 2 × earRadius.
struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var earRadius: CGFloat = 6

    // Радиус низа плавно анимируется при раскрытии.
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let ear = earRadius
        let left = rect.minX + ear      // левая стенка тела
        let right = rect.maxX - ear     // правая стенка тела
        let radius = max(0, min(bottomRadius, (right - left) / 2, rect.height - ear))

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Правое ухо: скругляем угол между верхней линией и правой стенкой.
        path.addArc(tangent1End: CGPoint(x: right, y: rect.minY),
                    tangent2End: CGPoint(x: right, y: rect.maxY),
                    radius: ear)
        // Нижний правый угол.
        path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY),
                    tangent2End: CGPoint(x: left, y: rect.maxY),
                    radius: radius)
        // Нижний левый угол.
        path.addArc(tangent1End: CGPoint(x: left, y: rect.maxY),
                    tangent2End: CGPoint(x: left, y: rect.minY),
                    radius: radius)
        // Левое ухо.
        path.addArc(tangent1End: CGPoint(x: left, y: rect.minY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY),
                    radius: ear)
        path.closeSubpath()
        return path
    }
}
