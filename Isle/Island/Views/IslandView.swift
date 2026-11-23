import SwiftUI

/// Корневой вид острова: чёрная форма + содержимое для текущего состояния.
struct IslandView: View {
    let model: IslandViewModel

    var body: some View {
        let size = model.size
        let ear = IslandViewModel.earRadius
        let shape = IslandShape(bottomRadius: model.bottomRadius, earRadius: ear)

        ZStack(alignment: .top) {
            shape.fill(Color.black)
            content
                .padding(.horizontal, ear)
        }
        .frame(width: size.width + ear * 2, height: size.height)
        .clipShape(shape)
        // Прижимаем остров к верхнему краю окна.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .compact(let compact):
            CompactView(content: compact,
                        notchWidth: model.geometry.notchSize.width,
                        nowPlaying: model.nowPlaying)
                .transition(Self.contentTransition)
        case .expanded:
            ExpandedView(model: model)
                .transition(Self.contentTransition)
        }
    }

    /// Содержимое появляется чуть позже фона: прозрачность + лёгкий масштаб.
    private static let contentTransition = AnyTransition.asymmetric(
        insertion: .opacity
            .combined(with: .scale(scale: 0.95, anchor: .top))
            .animation(IslandViewModel.animation.delay(0.08)),
        removal: .opacity.animation(.easeOut(duration: 0.12))
    )
}
