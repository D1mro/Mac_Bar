import SwiftUI

/// Текст песни в стиле Яндекс Музыки: крупные жирные строки,
/// текущая — яркая, остальные приглушены, плавная прокрутка за песней.
/// Клик по строке — перемотка к ней.
struct LyricsView: View {
    let player: NowPlayingService
    let lyrics: LyricsService

    var body: some View {
        switch lyrics.state {
        case .synced(let lines):
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                // Чуть заранее — строка загорается вместе с голосом, а не после.
                let time = player.elapsed(at: context.date) + 0.25
                SyncedLyrics(lines: lines,
                             current: lines.lastIndex { $0.time <= time },
                             onSelect: { player.seek(to: $0.time) })
            }
        case .plain(let text):
            ScrollView(showsIndicators: false) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .mask(Self.fadeMask)
        case .loading:
            ProgressView().controlSize(.small)
        case .notFound, .idle:
            VStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.system(size: 20))
                Text("Текст не найден")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    /// Строки плавно исчезают у верхнего и нижнего края.
    static let fadeMask = LinearGradient(
        stops: [.init(color: .clear, location: 0),
                .init(color: .black, location: 0.18),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1)],
        startPoint: .top, endPoint: .bottom
    )
}

private struct SyncedLyrics: View {
    let lines: [LyricLine]
    let current: Int?
    let onSelect: (LyricLine) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 30)
                    ForEach(lines) { line in
                        row(line)
                            .id(line.id)
                            .onTapGesture { onSelect(line) }
                    }
                    Color.clear.frame(height: 60)
                }
                .animation(.easeOut(duration: 0.35), value: current)
            }
            .mask(LyricsView.fadeMask)
            .onAppear { scroll(proxy, animated: false) }
            .onChange(of: current) { scroll(proxy, animated: true) }
        }
    }

    private func row(_ line: LyricLine) -> some View {
        let isCurrent = line.id == current
        let isPast = (current ?? -1) > line.id
        let distance = current.map { abs(line.id - $0) } ?? 3
        return Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white.opacity(isCurrent ? 1 : (isPast ? 0.28 : 0.4)))
            .blur(radius: distance >= 2 ? 0.6 : 0)
            .scaleEffect(isCurrent ? 1 : 0.97, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let current else { return }
        // Текущая строка — чуть выше середины, как в Яндекс Музыке.
        let anchor = UnitPoint(x: 0, y: 0.35)
        if animated {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { proxy.scrollTo(current, anchor: anchor) }
        } else {
            proxy.scrollTo(current, anchor: anchor)
        }
    }
}
