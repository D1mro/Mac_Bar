import SwiftUI

/// Компактный вид по бокам от выреза.
struct CompactView: View {
    let content: CompactContent
    let notchWidth: CGFloat
    let nowPlaying: NowPlayingService

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
        case .track:
            HStack(spacing: 8) {
                ArtworkView(image: nowPlaying.artwork, size: 22, cornerRadius: 6)
                Text(nowPlaying.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
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
        case .track:
            HStack {
                Text(nowPlaying.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
        }
    }
}
