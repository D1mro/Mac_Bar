import SwiftUI

/// Раскрытый остров: вкладки под вырезом и содержимое выбранной вкладки.
struct ExpandedView: View {
    @Bindable var model: IslandViewModel

    var body: some View {
        VStack(spacing: 10) {
            // Контент начинается ниже выреза.
            Color.clear.frame(height: model.geometry.notchSize.height)

            HStack(spacing: 6) {
                ForEach(IslandTab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
            }

            Group {
                switch model.selectedTab {
                case .music: MusicTab()
                case .camera: CameraTab()
                case .tools: ToolsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private func tabButton(_ tab: IslandTab) -> some View {
        let selected = model.selectedTab == tab
        return Button {
            withAnimation(IslandViewModel.animation) { model.selectedTab = tab }
        } label: {
            Label(tab.title, systemImage: tab.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(selected ? 0.14 : 0.08)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
