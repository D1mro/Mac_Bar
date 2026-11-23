import SwiftUI

/// Раскрытый остров: вкладки слева от выреза, ниже — содержимое вкладки.
struct ExpandedView: View {
    @Bindable var model: IslandViewModel

    var body: some View {
        VStack(spacing: 6) {
            notchRow

            Group {
                switch model.selectedTab {
                case .music: MusicTab(model: model)
                case .camera: CameraTab()
                case .tools: ToolsTab(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background(alignment: .bottomTrailing) { glow }
    }

    /// Полоса высотой с вырез: слева иконки вкладок, по центру — сам вырез.
    /// Так под вырезом остаётся больше места для плеера.
    private var notchRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: model.geometry.notchSize.width)

            Color.clear.frame(maxWidth: .infinity)
        }
        .frame(height: model.geometry.notchSize.height)
    }

    private func tabButton(_ tab: IslandTab) -> some View {
        let selected = model.selectedTab == tab
        return Button {
            withAnimation(IslandViewModel.animation) { model.selectedTab = tab }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                .frame(width: 28, height: 22)
                .background(Capsule().fill(.white.opacity(selected ? 0.14 : 0.06)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    /// Мягкое свечение цветом обложки из правого нижнего угла (только в плеере).
    /// Сверху гасится, чтобы полоса у выреза оставалась чёрной.
    @ViewBuilder
    private var glow: some View {
        if model.selectedTab == .music, model.nowPlaying.hasMedia {
            GeometryReader { geometry in
                let notch = model.geometry.notchSize.height
                RadialGradient(colors: [model.nowPlaying.accent.opacity(0.45), .clear],
                               center: .bottomTrailing,
                               startRadius: 0,
                               endRadius: geometry.size.width * 0.6)
                    .mask(
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .black, location: min((notch + 30) / geometry.size.height, 1))],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}
