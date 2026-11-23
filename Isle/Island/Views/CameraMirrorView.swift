import AppKit
import SwiftUI

/// Что показать в зеркале: превью камеры, загрузку или ошибку.
/// Сам камеру не включает — этим занимается владелец (вкладка или окошко).
struct CameraMirrorContent: View {
    let status: CameraService.StartResult?

    var body: some View {
        ZStack {
            Color.white.opacity(0.08)

            switch status {
            case .running:
                CameraPreview(session: CameraService.shared.session)
            case .denied:
                message(icon: "video.slash.fill",
                        text: String(localized: "Нет доступа к камере"),
                        showSettings: true)
            case .noCamera:
                message(icon: "video.slash.fill",
                        text: String(localized: "Камера не найдена"),
                        showSettings: false)
            case nil:
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func message(icon: String, text: String, showSettings: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 11))
            if showSettings {
                Button(String(localized: "Открыть настройки")) {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
            }
        }
        .foregroundStyle(.white.opacity(0.55))
        .padding(8)
    }
}
