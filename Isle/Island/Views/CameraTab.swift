import SwiftUI

/// Вкладка «Камера»: зеркало. Камера включается при открытии вкладки
/// и выключается, когда вкладку переключили или остров закрылся.
struct CameraTab: View {
    @State private var status: CameraService.StartResult?

    var body: some View {
        CameraMirrorContent(status: status)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { status = await CameraService.shared.start() }
            .onDisappear { CameraService.shared.stop() }
    }
}
