import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.setSession(session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.setSession(session)
    }
}

final class CameraPreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}
