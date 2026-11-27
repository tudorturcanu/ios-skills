import CoreLocation
import Observation

@Observable
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    enum AccessState { case notDetermined, denied, authorized }

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let cacheKey = "trailnear.cachedAuthStatus"

    private(set) var accessState: AccessState = .notDetermined
    private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        accessState = loadState()
    }

    /// Reads the authorization state once and persists it so launch is fast
    /// and we avoid flicker while CoreLocation spins up.
    private func loadState() -> AccessState {
        if let raw = defaults.object(forKey: cacheKey) as? Int,
           let cached = CLAuthorizationStatus(rawValue: Int32(raw)) {
            return map(cached)
        }
        let live = manager.authorizationStatus
        defaults.set(Int(live.rawValue), forKey: cacheKey)
        return map(live)
    }

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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}
