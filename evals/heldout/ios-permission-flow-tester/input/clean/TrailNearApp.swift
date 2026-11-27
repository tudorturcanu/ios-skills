import SwiftUI

@main
struct TrailNearApp: App {
    @State private var permission = LocationPermissionManager()

    var body: some Scene {
        WindowGroup {
            NearbyView()
                .environment(permission)
        }
    }
}
