import SwiftUI

@main
struct LumenApp: App {
    @State private var entitlements = EntitlementManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
                .task {
                    // Establish state from the user's current entitlements at launch.
                    await entitlements.refresh()
                }
        }
    }
}
