# TrailNear location permission: read-only source review

Scope: CONTEXT.md, Info.plist, TrailNearApp.swift, LocationPermissionManager.swift, NearbyView.swift. Nothing was built or run.

## Verdict
I found no defect in the provided source that explains the reported symptom (Settings changed to "While Using", app still shows "Location is off"). The permission flow in this revised build reads correctly. I am not going to invent a cause.

## Evidence the flow is correct
- Live status, nothing persisted: LocationPermissionManager.swift:16 sets `accessState = map(manager.authorizationStatus)` in init. The comment at line 19 says nothing is persisted, and the file has no UserDefaults or other cache. So a relaunch after the user changes Settings re-reads the system value. This matches the "force-quit does not help" claim only if the system still reports denied, which the source cannot cause.
- Delegate wired: line 15 sets `manager.delegate = self` before any status use. `locationManagerDidChangeAuthorization(_:)` (lines 41-48) re-maps `manager.authorizationStatus` into `accessState`, and starts or stops updates. This is the correct modern (iOS 14+) callback. It fires once after the delegate is set and again on Settings changes.
- State mapping: lines 20-27 map `.authorizedWhenInUse` and `.authorizedAlways` to `.authorized`, and `.denied` and `.restricted` to `.denied`. There is no latch or one-way transition: any status can map back to any state.
- Guards are not sticky: `requestAccess()` (line 30) only guards on `.notDetermined`, which is correct (the system never re-prompts after a decision). `startUpdates()` guards on `.authorized`, which is live.
- UI reacts: NearbyView.swift:4 reads the manager from the environment. The type is `@Observable` (line 4 of the manager), `accessState` is a tracked stored property, and the switch at NearbyView.swift:8 re-evaluates when it changes. TrailNearApp.swift:5 holds it in `@State`, which is the correct iOS 17 pattern for an `@Observable` root object, and it is created once per app lifetime.
- Info.plist:9-10 contains `NSLocationWhenInUseUsageDescription`, which is required for the when-in-use prompt. This is consistent with the first-run prompt working on fresh installs.
- Threading: the manager is created on the main thread (via the App struct's `@State` initial value), so delegate callbacks arrive on the main thread and the `accessState` mutation is safe for SwiftUI.

## Things I could not verify from source alone
- `TrailListView` (NearbyView.swift:24) is not among the provided files. If trails "not loading" is observed after the banner clears, the cause could be there, for example it treating a nil `lastLocation` as "nothing to show". Unknown.
- Whether a fix arrives at all after authorization: needs a device. `lastLocation` is nil until the first `didUpdateLocations`. There is no `didFailWithError` handler (see minor items), so a failure would be silent.
- The actual runtime behavior in the user reports (system status value after the Settings change, relaunch behavior, whether the shipped build is really this revised code). CONTEXT.md says the same complaint applies to the previous build, so it is worth confirming the affected users are actually on this revision and that the previous build's code is what caused the bug.
- Info.plist here is a minimal stub (no CFBundleExecutable, version keys, etc.), so I cannot judge the real project's plist. A real Info.plist or build setting could, for example, be missing the usage-description key in the shipping target. The key is present here.
- Whether a Settings change kills and relaunches the app on a given iOS version. Both paths (relaunch via init, or live delegate callback) are handled by this code.

## Minor, non-causal observations (optional)
1. `.restricted` maps to `.denied` (line 23), so a parentally/MDM-restricted user sees "Open Settings", which cannot help them. Consider a separate `.restricted` state with different copy.
2. No `locationManager(_:didFailWithError:)` implementation (LocationPermissionManager.swift). Errors are swallowed; add one to surface failures.
3. Reduced accuracy (`manager.accuracyAuthorization`) is not handled. Not relevant to the complaint.
4. `startUpdates()` (called from `.onAppear`, NearbyView.swift:25) duplicates the start already done in the delegate (line 44). Harmless; `startUpdatingLocation` is idempotent.
5. `UIApplication` is used in NearbyView.swift:18-19 with only `import SwiftUI`. This compiles on iOS because SwiftUI re-exports UIKit; no action needed.

## What to change
Nothing required in the provided files for this complaint. Next steps are diagnostic: confirm the build the affected users run, inspect `TrailListView`, and reproduce on a device (deny, change in Settings, return) while logging `manager.authorizationStatus` in `locationManagerDidChangeAuthorization`.
