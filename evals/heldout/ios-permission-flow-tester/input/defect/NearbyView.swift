import SwiftUI

struct NearbyView: View {
    @Environment(LocationPermissionManager.self) private var permission

    var body: some View {
        Group {
            switch permission.accessState {
            case .notDetermined:
                VStack(spacing: 12) {
                    Text("Find trails near you")
                    Button("Allow Location") { permission.requestAccess() }
                }
            case .denied:
                VStack(spacing: 12) {
                    Text("Location is off")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            case .authorized:
                TrailListView(location: permission.lastLocation)
                    .onAppear { permission.startUpdates() }
            }
        }
    }
}
