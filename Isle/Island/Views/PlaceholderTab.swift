import SwiftUI

/// Временное содержимое вкладки, пока она не реализована.
struct PlaceholderTab: View {
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text("Скоро")
                .font(.system(size: 12))
        }
        .foregroundStyle(.white.opacity(0.55))
    }
}
