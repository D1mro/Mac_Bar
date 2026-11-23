import AVFoundation
import SwiftUI

/// Превью камеры, отражённое как зеркало.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.applyMirroring()
    }

    final class PreviewView: NSView {
        private let previewLayer: AVCaptureVideoPreviewLayer

        init(session: AVCaptureSession) {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            super.init(frame: .zero)
            wantsLayer = true
            layer = previewLayer
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

        override func layout() {
            super.layout()
            applyMirroring()
        }

        /// Зеркалим явно: соединение появляется, только когда камера подключена.
        func applyMirroring() {
            guard let connection = previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
