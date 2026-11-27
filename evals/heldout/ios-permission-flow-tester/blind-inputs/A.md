# TrailNear location permission: source review (revised build)

Scope: read-only review of Info.plist, TrailNearApp.swift, LocationPermissionManager.swift, NearbyView.swift, CONTEXT.md. Nothing was built or run.

## Verdict

I found no defect in the supplied source that explains the reported symptom. The revised build reads correctly for the Settings-recovery path. I am not going to invent a bug. Whether the revised build still fails can only be settled by running it (see "Could not verify").

## Resource inventory

- Framework: CoreLocation, when-in-use authorization via `requestWhenInUseAuthorization()` (LocationPermissionManager.swift:31). Continuous updates via `startUpdatingLocation()` (lines 36, 44).
- Usage description: `NSLocationWhenInUseUsageDescription` is present with a meaningful string (Info.plist:9-10). No Always key is needed, since nothing requests Always. No extensions are in the supplied files.
- Scope is appropriate (when-in-use only). `.authorizedAlways` is mapped to authorized (line 24), which is harmless.

## Transition trace

| Scenario | Code path | Result from source |
| --- | --- | --- |
| Fresh install | init reads `manager.authorizationStatus` -> `.notDetermined` (lines 16, 22); view shows "Allow Location" (NearbyView:9-13); tap calls `requestAccess()`, guarded by notDetermined (lines 29-32) | Prompt requested in context, from a user tap. Matches the report that the first prompt works. |
| Allow | Delegate `locationManagerDidChangeAuthorization` sets state to authorized and starts updates (lines 41-45); the view also calls `startUpdates()` on appear (NearbyView:25) | Correct. Starting twice is harmless. |
| Don't Allow | Same delegate -> `.denied`; view shows "Location is off" + Open Settings (NearbyView:14-22) | Correct. No repeated prompt is attempted, since the request is guarded. |
| Change to While Using in Settings, return | `authorizationStatus` is read live (line 42) in the delegate. It is a non-optional, non-cached read, and nothing is persisted (comment at line 19). The state goes to authorized and the view switches to `TrailListView` | Correct per the documented behavior in CONTEXT.md:11. |
| Force-quit / relaunch | init re-reads the live status (line 16) | Correct. No stored boolean could pin a stale "denied". |
| Restricted | Mapped into the same `.denied` bucket (line 23) | See minor note 1. |

Specific things I checked that could have caused the reported "stuck on denied even after force-quit" symptom, and ruled out in this source:

- Persisted flag (UserDefaults, Keychain, `@AppStorage`): none exists. Grep of all four files shows no storage of permission state.
- Request guard blocking recovery: `requestAccess()` only runs from the notDetermined UI branch, and `.denied` never depends on it.
- Delegate never set or set too late: `manager.delegate = self` is set in init (line 15) before reading status. The manager is retained as a `let` property, and the manager object itself is retained by the `@State` in the App (TrailNearApp:5).
- Wrong status API: the instance property `manager.authorizationStatus` is used (the iOS 14+ form), not the deprecated class method.
- Object recreated or not observed: the `@Observable` class is held in `@State` at the App level (not in a View struct that is re-initialized) and injected with `.environment(permission)` (TrailNearApp:10). `NearbyView` reads `accessState` in `body`, so the observation tracks it. `@Observable` on an `NSObject` subclass is supported.
- Switch exhaustiveness: `@unknown default` maps to denied (line 25). This is a safe fallback for future states and not a cause of the symptom on current SDKs.
- Missing plist key: the key is present, so the prompt appears (consistent with the first-run report).

Because the status is read live from the system and the view derives directly from it, a user who has moved to While Using in Settings should land in `.authorized`. The code as written supports recovery, so the complaint's cause is not visible in these files.

## Minor observations (not the reported bug)

1. `.denied` and `.restricted` are collapsed (LocationPermissionManager.swift:23). The "Location is off" banner and Open Settings button are therefore also shown for restricted (parental controls/MDM), where Settings cannot help. Also, location services being disabled device-wide is not distinguished (`CLLocationManager.locationServicesEnabled()` is never checked). Optional improvement: add a `.restricted` state with different copy.
2. Accuracy is ignored. `manager.accuracyAuthorization` (`.reducedAccuracy`) is never inspected. Reduced accuracy still counts as authorized here, which is acceptable for a trail list, but the app does not know or tell the user.
3. No `locationManager(_:didFailWithError:)` is implemented (lines 50-52 are the only other delegate method). Location failures, such as unavailable location while authorized, produce no state, so they would look like "authorized but nothing loads". This is unavailability being conflated with permission only in the sense that it is not surfaced at all.
4. Stale data: when access is revoked, `stopUpdatingLocation()` runs (line 46) but `lastLocation` is not cleared. It is harmless now because the view shows the denied branch, but the old fix would resurface stale coordinates on a later re-grant until a fresh fix arrives. Consider clearing it.
5. Concurrency: the class is not `@MainActor` although it mutates observed state from delegate callbacks. CoreLocation delivers on the thread where the manager was created (main), so it works in practice. Under Swift 6 strict concurrency it will warn. Optional: annotate `@MainActor`.
6. `TrailListView` is used (NearbyView.swift:24) but is not in the supplied files. If it shows a spinner while `lastLocation == nil` with no timeout or failure state, then "authorized but no trails" and an indefinite loader are possible. This is outside the permission logic, but it is the most plausible place for a "no trails load" symptom if the user really does reach the authorized branch.
7. Info.plist is minimal (no `CFBundleVersion`, `CFBundleShortVersionString`, `CFBundleExecutable`, etc.). This is likely just a trimmed sample for the review. I could not verify the real built target's merged plist.

## Could not verify from source alone

- Whether the shipped binary behind the complaint matches this "revised build". CONTEXT.md:11 says the same complaint text applied to the previous build. Confirm the reporters are actually on the revised build and not the previous one.
- Real system behavior: the Settings round trip, whether iOS terminates the app on the permission change (relaunch then re-reads status), and the real prompt. These need a device or simulator, and hardware location behavior is not established by simulator results.
- `TrailListView` behavior, and any code not provided (for example network trail fetching, other files that might cache a denied state or use a separate CLLocationManager).
- Built-target plist contents, entitlements, and signing.

## Suggested next steps

- No change is required in the permission logic for the reported recovery path.
- Manual test matrix on a disposable simulator and a real device: fresh install -> Don't Allow -> Settings -> While Using -> return (and again after force-quit); record how the state was set. Observe `accessState` and `manager.authorizationStatus` at each step. Add logging in `locationManagerDidChangeAuthorization` to confirm it fires. If the banner still shows after this, the logged status will tell which layer is wrong.
- Inspect `TrailListView` for a loading state that has no failure/timeout branch.
- Optionally implement notes 1-4 above.
