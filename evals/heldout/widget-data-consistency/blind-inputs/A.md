# Review: stale / inconsistent TideWatch widget data

Scope: read-only review of CONTEXT.md, App/TideSync.swift, App/SharedStore.swift, Widget/TideWidget.swift and both entitlements files. Nothing was built or run.

## Primary finding: reload is requested before the data is saved (ordering bug)

App/TideSync.swift:18-26 in `refresh()`:

- line 19: fetch the snapshot
- line 22: `WidgetCenter.shared.reloadAllTimelines()`
- line 24: `SharedStore.save(snapshot)`

The reload is requested before the new snapshot is written. WidgetKit runs `getTimeline` asynchronously in the widget extension process. `getTimeline` (Widget/TideWidget.swift:18-22) reads `SharedStore.load()` at line 19. If that read lands before line 24 has executed, or before the write is visible to the extension, the widget builds its entry from the previous snapshot. It then holds that entry until the policy `.after(next)` (30 minutes, lines 21-22) or until the next reload.

This matches the report: the widget shows the previous value and "catches up the next time I refresh", because the next refresh's `reloadAllTimelines()` runs after the previous refresh's save. "Sometimes a whole refresh behind" fits the race being timing-dependent. The extension can launch quickly or already be warm, in which case the old value is read. When the extension is slower, the new value is read and the widget looks correct, so the failure is intermittent.

Caveat: the exact timing is not specified by Apple. `reloadAllTimelines()` may be coalesced or delayed, so the failure may be rare in some conditions. Even so, the ordering is wrong by construction, and no ordering guarantee exists in the opposite direction.

Fix: save first, reload second.

```swift
let snapshot = try await api.fetchNextHighTide(harbor: harbor)
SharedStore.save(snapshot)
WidgetCenter.shared.reloadAllTimelines()   // or reloadTimelines(ofKind: "TideWidget")
return snapshot
```

## Secondary findings

1. `SharedStore.save` is fire-and-forget and swallows errors (App/SharedStore.swift:19-22). An encode failure hits `guard ... else { return }` silently. Nothing tells `refresh()` the save failed, so it still reloads the widget and returns the new snapshot to the UI. The app would then show new data while the widget shows old data, with no log. Suggest making `save` return a Bool or throw, and logging failures.

2. `UserDefaults(suiteName:)!` is force-unwrapped (App/SharedStore.swift:15-17). It returns nil if the app group is not provisioned for that target, which would crash. If the group works, this is fine. If it does not, you get a crash rather than staleness, so it does not explain the symptom. It is a robustness issue.

3. Cross-process `UserDefaults` visibility. The app writes and the extension reads through separate process-level caches of the same suite. `UserDefaults` normally syncs cross-process, but there is no explicit `synchronize()`. This is generally not needed on modern iOS, though visibility is not strictly guaranteed to be instantaneous. This increases the impact of the ordering bug above. Switching to a file in the group container, written atomically, would give a clearer guarantee. This is optional.

4. Weak fallback refresh policy (Widget/TideWidget.swift:21-22). The timeline has a single entry and refreshes after 30 minutes, and the widget never fetches data itself. If the app is not opened, the widget never updates from the network. The data is also only as fresh as the app's last refresh. This is a design limitation and not a bug, but it contributes to "stale" perceptions. Options are a background refresh in the app, or network fetching inside `getTimeline`.

5. The entry `date` is `.now` and the widget view displays `nextHighTide` with no check of whether it is in the past (Widget/TideWidget.swift:20, 32). After the high tide passes, the widget keeps showing a past time until the app refreshes. The timeline could instead contain entries keyed to tide times, or the view could mark past times as stale. `fetchedAt` exists in the model but is never used by the widget.

6. `reloadAllTimelines()` vs `reloadTimelines(ofKind:)`. The all-timelines call works for a single widget. Using the specific kind (`"TideWidget"`, line 44) is more precise and is a minor improvement. It is not a defect.

7. Refresh triggers. The comment at TideSync.swift:17 says `refresh()` is called on pull-to-refresh and when the app becomes active. The call sites are not in the provided source. Whether the widget is also reloaded when the harbor changes, or from any other path that updates `SharedStore`, cannot be verified.

## Ruled out from the source

- Entitlements: App/App.entitlements:5-7 and Widget/Widget.entitlements:5-7 declare the same app group `group.com.example.tidewatch`, which matches `SharedStore.groupID` (SharedStore.swift:12). No mismatch or typo is visible here.
- Key and model: both sides use the same `SharedStore` with the same key `tide.snapshot.v1` and the same `Codable` type, so there is no schema or key divergence in the source, assuming the file really is a member of both targets as the comment on SharedStore.swift:10 states.

## What I could not verify from source alone

- Whether `SharedStore.swift` is really compiled into both targets (only the comment claims it).
- That the provisioning profiles for both targets actually include the app group on the TestFlight build. Entitlements files alone do not prove this. If the group were missing in the extension, `UserDefaults(suiteName:)` would behave differently and the widget would likely show "Open TideWatch" and not an old value, so this is unlikely to be the cause.
- The actual runtime ordering and timing of WidgetKit's `getTimeline` call relative to the save (the race is inferred, not observed). No logs exist.
- Where and how often `refresh()` is called, and whether the UI/app view model does any other `SharedStore.save` calls.
- Whether WidgetKit's reload budget throttles reloads on the TestFlight build. Reload requests from the foreground app are generally not budgeted, but this is device and OS behavior that source cannot confirm.
- `TideAPI` behavior (e.g., whether the API returns a cached or stale tide itself).

## Recommended changes (in priority order)

1. Swap lines 22 and 24 in TideSync.swift so `SharedStore.save` happens before `reloadAllTimelines()` (or use `reloadTimelines(ofKind: "TideWidget")`). This is the fix for the reported symptom.
2. Make `SharedStore.save` report failure and log it. Only reload the widget when the save succeeded.
3. Optionally, harden storage and the widget policy (unwrap the suite safely, build timeline entries around `nextHighTide`, show or flag stale data using `fetchedAt`).
4. Add a temporary log of `fetchedAt` in both `save` and `getTimeline` so a TestFlight tester's logs would confirm the ordering hypothesis.
