import SwiftUI
import KeyboardShortcuts

/// Вкладка «Инструменты»: плитки быстрых действий.
struct ToolsTab: View {
    let model: IslandViewModel

    var body: some View {
        HStack(spacing: 10) {
            ToolTile(icon: "camera.viewfinder",
                     title: String(localized: "Скриншот"),
                     hint: KeyboardShortcuts.getShortcut(for: .takeScreenshot)?.description) {
                model.takeScreenshot()
            }
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Плитка инструмента: иконка, название и подсказка (например, горячая клавиша).
private struct ToolTile: View {
    let icon: String
    let title: String
    var hint: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                if let hint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 92, height: 74)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(isHovered ? 0.14 : 0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
