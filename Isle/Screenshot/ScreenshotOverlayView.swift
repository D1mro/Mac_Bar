import SwiftUI

/// Рисует подсветку окна под курсором, выделяемую рамку и кнопку «Весь экран».
struct ScreenshotOverlayView: View {
    let size: CGSize
    let windows: [CapturableWindow]
    let onFinish: (ScreenshotSelection) -> Void

    @State private var hovered: CapturableWindow?
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    /// Рамка выделения — появляется, только если мышь протянули дальше 4 pt.
    private var selection: CGRect? {
        guard let a = dragStart, let b = dragCurrent,
              hypot(b.x - a.x, b.y - a.y) > 4 else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Почти прозрачный фон: полностью прозрачные пиксели пропускают клики насквозь.
            Color.black.opacity(0.01)

            if let rect = selection {
                selectionLayer(rect)
            } else if let window = hovered {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: window.frame.width, height: window.frame.height)
                    .offset(x: window.frame.minX, y: window.frame.minY)
                    .allowsHitTesting(false)
            }

            if selection == nil {
                fullScreenButton
                    .position(x: size.width / 2, y: size.height * 0.18)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            NSCursor.crosshair.set()
            if case .active(let point) = phase, dragStart == nil {
                hovered = windows.first { $0.frame.contains(point) }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil { dragStart = value.startLocation }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    if let rect = selection {
                        onFinish(.region(rect))
                    } else if let window = windows.first(where: { $0.frame.contains(value.location) }) {
                        onFinish(.window(window.id))
                    }
                    dragStart = nil
                    dragCurrent = nil
                }
        )
    }

    /// Затемнение вокруг выделенной области, белая рамка и размер.
    private func selectionLayer(_ rect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)

            Text("\(Int(rect.width)) × \(Int(rect.height))")
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .offset(x: rect.maxX + 6, y: rect.maxY + 6)
        }
        .allowsHitTesting(false)
    }

    private var fullScreenButton: some View {
        VStack(spacing: 8) {
            Button {
                onFinish(.region(CGRect(origin: .zero, size: size)))
            } label: {
                Label(String(localized: "Весь экран"), systemImage: "display")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Text("Выделите область или нажмите на окно · Esc — отмена")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 3)
                .allowsHitTesting(false)
        }
    }
}
