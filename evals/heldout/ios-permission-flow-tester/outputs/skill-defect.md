# TrailNear location permission: source review (read-only)

## Root cause
Authorization is cached in UserDefaults and never refreshed from CoreLocation. The code has no authorization-change handling at all.

Evidence (LocationPermissionManager.swift):
- Lines 21-31 `loadState()`: the first launch reads `manager.authorizationStatus` and writes it to `UserDefaults` under `trailnear.cachedAuthStatus` (line 29). Every later launch returns the cached value (lines 24-26) and never consults the live status. The cache has no invalidation. This is why force-quitting does not help, and why only deleting the app (which wipes UserDefaults) does.
- The class conforms to `CLLocationManagerDelegate` and sets `manager.delegate = self` (line 17). It implements only `didUpdateLocations` (line 52). There is no `locationManagerDidChangeAuthorization(_:)`, so the app never learns of a change. This applies both to the result of the in-app prompt and to a change made in Settings. `accessState` is `private(set)` and is assigned only in `init` (line 18).
- Nothing re-queries status when the app returns to the foreground. NearbyView.swift has no `scenePhase` observer or `.onChange`, and TrailNearApp.swift has none either. After the user returns from Settings, the manager holds the old state.
- Delegate caveat: `CLLocationManager` calls `locationManagerDidChangeAuthorization` once after the delegate is set. That call is the idiomatic hook for re-reading status. Because it is not implemented, the app misses it.

## Mapping to the reported symptom
- The "Location is off" banner with Open Settings is the `.denied` branch (NearbyView.swift lines 14-22). `.authorized` (line 23) is the only branch that shows trails and calls `startUpdates()`, and `startUpdates()` is itself guarded on `accessState == .authorized` (line 48). With the state stuck at `.denied`, nothing loads.
- Fresh-install prompt works: `.notDetermined` shows "Allow Location" (line 12), which calls `requestAccess()` (lines 42-45) and triggers the system prompt.
- Discrepancy to flag: following the code literally, the cache is first written at first launch, when status is `notDetermined`. The cache would therefore hold `0` and never become `.denied`, so the banner would not appear after Don't Allow. It would keep showing "Allow Location", and `requestAccess()` would call the manager again, which the OS ignores. Something not in these files must be writing a denied value to the cache. Two possibilities: an earlier build of the app, or a launch where status was already denied. I cannot confirm which from source. Either way the same defect explains the complaint, and the same defect would also break first-run acceptance: after tapping Allow, `accessState` would never move to `.authorized`.

## Other findings
1. `requestAccess()` guards on the cached `accessState == .notDetermined` (line 43). A stale cache can block or wrongly allow the request.
2. `.denied` and `.restricted` are collapsed (line 36). The UI shows "Open Settings" even when a parental or MDM restriction means Settings cannot help. This is minor and should be a separate state.
3. There is no handling of reduced accuracy (`accuracyAuthorization`). The feature (trails nearby) may be fine with approximate location. This is not verifiable from source and is not necessarily a bug.
4. There is no `didFailWithError` delegate method. A failure of location services such as being disabled system-wide is indistinguishable from a denial. Also no distinction exists between "authorized but no fix yet" and an empty result. `TrailListView` is not in the provided files, so its loading and empty states are not reviewed.
5. Info.plist is fine for the stated scope: `NSLocationWhenInUseUsageDescription` is present (lines 9-10). It is a source-file check only, not verified in a built target. The plist has no Always keys, which matches the when-in-use scope.

## What to change
1. Remove the UserDefaults cache entirely (`defaults`, `cacheKey`, and the cache branch of `loadState`). The live value of `manager.authorizationStatus` is cheap to read. Initialize with `accessState = map(manager.authorizationStatus)`.
2. Implement the delegate callback:
```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    accessState = map(manager.authorizationStatus)
    if accessState == .authorized { manager.startUpdatingLocation() }
    else { manager.stopUpdatingLocation() }
}
```
3. Add a defensive refresh on foreground, for example `.onChange(of: scenePhase) { if $1 == .active { permission.refresh() } }`, where `refresh()` re-reads `manager.authorizationStatus`.
4. Split `.restricted` from `.denied` in `AccessState` and adjust the banner text.
5. Handle `didFailWithError`, and make sure `TrailListView` ends loading when there is no location.
6. Regression test: with a fake provider, start at denied, switch to authorizedWhenInUse, simulate the delegate callback or the scene becoming active, and assert the authorized UI and that updates start.

## Not verifiable from source
- Actual runtime behavior, including the delegate-after-assignment callback and the Settings round trip. These need a device or simulator.
- The source of the denied value in the cache (see the discrepancy above).
- `TrailListView` behavior and the built target's Info.plist.
- Real prompt behavior and hardware or accuracy behavior.
