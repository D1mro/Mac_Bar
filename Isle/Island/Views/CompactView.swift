import SwiftUI

/// Компактный вид: слева и справа от выреза по 60 pt.
struct CompactView: View {
    let content: CompactContent
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(maxWidth: .infinity)
            Color.clear.frame(width: notchWidth)   // место под физический вырез
            trailing.frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var leading: some View {
        switch content {
        case .notification(let notification):
            Image(systemName: notification.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        case .music:
            // Обложка появится на этапе 4.
            RoundedRectangle(cornerRadius: 5)
                .fill(.white.opacity(0.14))
                .frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch content {
        case .notification(let notification):
            Text(notification.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
        case .music:
            // Звуковой бар появится на этапе 4.
            Image(systemName: "waveform")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
