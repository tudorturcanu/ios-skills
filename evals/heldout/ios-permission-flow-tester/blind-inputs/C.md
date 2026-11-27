# TrailNear location permission: source review (read-only)

## Verdict
There is a real defect. The app treats a value cached in UserDefaults as the source of truth for authorization and never refreshes it from CoreLocation. This explains why changing the permission in Settings has no effect, and why only a reinstall (which wipes UserDefaults) fixes it.

## Findings

### 1. Cached authorization status is never invalidated (root cause)
`LocationPermissionManager.swift` lines 15-19 and 23-31:
- `init()` sets `accessState = loadState()`.
- `loadState()` first checks `defaults.object(forKey: cacheKey)` (line 24). If a value exists, it returns `map(cached)` immediately (line 26) and never reads `manager.authorizationStatus`.
- The live status is read (line 28) and written to the cache (line 29) only when no cache exists, which is the first launch ever.
- A grep of the code finds no other place that writes `cacheKey`.

Consequences:
- If the cache holds denied, it stays denied across relaunches and force-quits (matches "force-quitting does not help"). Changing the setting in Settings > TrailNear > Location is never observed.
- Reinstall clears UserDefaults, so the cache is rebuilt from the live status (matches "only reinstalling fixes it").
- The first-run prompt works because on a fresh install there is no cache, so the live `.notDetermined` is used (matches the report).
- The comment on lines 21-22 ("fast launch / avoid flicker") describes an optimization that is wrong for permission state. `CLLocationManager.authorizationStatus` is a cheap property read and the user can change it outside the app at any time.

### 2. No authorization-change delegate callback
`LocationPermissionManager.swift` lines 52-54: the only delegate method is `didUpdateLocations`. There is no `locationManagerDidChangeAuthorization(_:)`. Nothing updates `accessState` after the system prompt is answered, after the user changes Settings while the app is backgrounded, or on return to the foreground. `accessState` is `private(set)` and assigned only in `init` (line 18). So even without the cache, a change made while the app is running (the user's flow: Settings, then back to the app) would not be reflected. This is the second half of the same bug, and both must be fixed.

### 3. Related consequence: the prompt result is not reflected in the same session
Because of finding 2, after the user taps Allow or Don't Allow on a fresh install, `accessState` stays `.notDetermined` (NearbyView line 9 keeps showing "Allow Location") until the next launch. Reading the source, `requestAccess()` (line 42-45) also never moves state forward. This is a latent bug related to the reported one, though the support report says the first-run prompt "appears correctly" (the prompt appearing is consistent; what happens after is not described).

### 4. Gap between the reported symptom and the code
Tracing the code literally for the described flow (fresh install, tap Don't Allow, never get a status update), the cache would be written once as `0` (`.notDetermined`) at first launch, and the banner shown afterwards would be "Allow Location" (NearbyView lines 9-13), not "Location is off". `requestAccess()` would then call `requestWhenInUseAuthorization()`, which does nothing once the status is denied. The "Location is off" banner (NearbyView lines 14-22) only appears if the cache holds denied/restricted (raw 1 or 2). That could happen if an earlier build or version stored the denied value, or if the first launch happened with the status already denied, but I cannot confirm it from these files. The core defect (stale cache plus no delegate refresh) holds in either case, and the fix below removes both. I could not verify which exact path the affected users hit.

### 5. Minor / not verified
- `TrailListView` is referenced (NearbyView line 24) but not provided. I cannot check how it handles a nil location or whether it loads data.
- No `locationManager(_:didFailWithError:)` is implemented. This is not part of the reported problem.
- `startUpdates()` is called from `.onAppear` (NearbyView line 25). If state flips to `.authorized` while the view is on screen, the switch re-renders into the `.authorized` branch and `onAppear` fires, so this should work once state updates correctly. That is a reading of SwiftUI behavior, not tested.
- `Info.plist` contains `NSLocationWhenInUseUsageDescription` (lines 9-10), so the key is present and correct for when-in-use. The plist is minimal (no CFBundleExecutable etc.), which is likely just an excerpt. Nothing here is wrong for the reported issue.
- `TrailNearApp.swift` is fine: a single manager is created via `@State` and passed in the environment. Observation of `accessState` through `@Observable` works for the view.
- Not verifiable without a device or simulator: actual CoreLocation callback timing, whether `locationManagerDidChangeAuthorization` fires on return from Settings (it normally does on iOS 14+, and the app may also be relaunched by the system when permissions change), and the existing contents of affected users' UserDefaults.

## What to change
1. Remove the UserDefaults cache entirely (`defaults`, `cacheKey`, the cache branch of `loadState`). Initialize with `accessState = map(manager.authorizationStatus)`.
2. Add the delegate method, which is the standard place to track authorization:
```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    accessState = map(manager.authorizationStatus)
    if accessState == .authorized { manager.startUpdatingLocation() }
}
```
   CoreLocation calls this when the delegate is set and on every change, including changes made in Settings.
3. Optionally also refresh when the app returns to the foreground (`scenePhase == .active` calls `refresh()`, which re-reads `manager.authorizationStatus`), as a safety net.
4. If you want to keep a cache for flicker, never use it as authority: treat it only as an initial placeholder and always overwrite it from the live status. Also delete the stale key `trailnear.cachedAuthStatus` once (for example in `init`) so already-affected users recover on the next update without reinstalling. Removing the cache read (item 1) already fixes them, since the live status will be used on next launch.
5. Add `locationManager(_:didFailWithError:)` for completeness (optional).

Files reviewed (all under the project directory): CONTEXT.md, Info.plist, TrailNearApp.swift, LocationPermissionManager.swift, NearbyView.swift. Nothing was built, run or modified.
