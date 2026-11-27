# TrailNear - location permission

TrailNear is a small iOS 17 app that lists hiking trails near the user. Location is requested with when-in-use authorization via CLLocationManager.

Support complaint (several users): "I tapped Don't Allow the first time. Later I went to Settings > TrailNear > Location and set it to While Using the App, then switched back to the app. It still shows the 'Location is off' banner with the Open Settings button, and no trails load. Force-quitting does not help. Only deleting and reinstalling the app fixes it."

The same users report the first-run prompt appears correctly on a fresh install.

Files: Info.plist, LocationPermissionManager.swift, NearbyView.swift, TrailNearApp.swift.

Documented context: CLLocationManager.authorizationStatus is read live from the system each time, and the delegate callback locationManagerDidChangeAuthorization(_:) fires when the user changes the setting in Settings and returns to the app. (Same complaint text above applies to the previous build; this is the revised build.)
