import SwiftUI
import VisionKit

/// Wraps VNDocumentCameraViewController. Camera access is requested by the
/// system the first time the scanner is presented.
struct ScannerView: UIViewControllerRepresentable {
    let onFinish: (Data) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (Data) -> Void
        init(onFinish: @escaping (Data) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ c: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            onFinish(Data())  // PDF rendering omitted in this excerpt
            c.dismiss(animated: true)
        }
    }
}
