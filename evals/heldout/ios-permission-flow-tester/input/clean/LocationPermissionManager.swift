import CoreLocation
import Observation

@Observable
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    enum AccessState { case notDetermined, denied, authorized }

    private let manager = CLLocationManager()

    private(set) var accessState: AccessState = .notDetermined
    private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        accessState = map(manager.authorizationStatus)
    }

    /// The system is the source of truth; nothing is persisted.
    private func map(_ status: CLAuthorizationStatus) -> AccessState {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        @unknown default: return .denied
        }
    }

    func requestAccess() {
        guard accessState == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        guard accessState == .authorized else { return }
        manager.startUpdatingLocation()
    }

    /// Called at creation and whenever the authorization changes, including
    /// changes made in Settings while the app is backgrounded.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        accessState = map(manager.authorizationStatus)
        if accessState == .authorized {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}
