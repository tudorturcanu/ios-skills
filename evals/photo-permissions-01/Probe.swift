import UIKit
import Photos
import PhotosUI

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Probe", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ProbeController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class ProbeController: UIViewController, PHPickerViewControllerDelegate {
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Photo authorization probe"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        if ProcessInfo.processInfo.arguments.contains("--picker") {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            present(picker, animated: false) { [weak self] in
                self?.record(pickerPresented: self?.presentedViewController is PHPickerViewController)
            }
        } else {
            record(pickerPresented: false)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: false)
    }

    private func record(pickerPresented: Bool) {
        let observation: [String: Any] = [
            "read_write": PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue,
            "add_only": PHPhotoLibrary.authorizationStatus(for: .addOnly).rawValue,
            "picker_presented": pickerPresented,
            "os": UIDevice.current.systemVersion,
            "pid": ProcessInfo.processInfo.processIdentifier
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys])
            let url = URL.documentsDirectory.appending(path: "observation.json")
            try data.write(to: url, options: .atomic)
        } catch {
            fatalError("Could not write probe observation: \(error)")
        }
    }
}
