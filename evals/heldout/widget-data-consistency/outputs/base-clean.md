# TideWatch widget staleness: read-only source review

Files reviewed: CONTEXT.md, App/TideSync.swift, App/SharedStore.swift, Widget/TideWidget.swift, both entitlements files. There is no Xcode project, Info.plist or provisioning data in the directory. Nothing was built or run.

## Summary
The source has no clear logic bug that explains "widget one refresh behind". The write-then-reload sequence and the App Group wiring look correct on paper. The most plausible source-level suspect is a cross-process visibility race in how the snapshot is written and then read. It is a hypothesis, not a proven cause. Several other causes cannot be checked from source (see below).

## What checks out (evidence)
- App Group id is identical in all three places: SharedStore.swift:12, App/App.entitlements:7, Widget/Widget.entitlements:7. A typo mismatch is ruled out at the source level.
- Both app and widget use the same key (`tide.snapshot.v1`, SharedStore.swift:13) and the same Codable type (SharedStore.swift:3-8). The file header (line 10) says it belongs to both targets, but that is unverifiable here.
- Ordering in TideSync.refresh is save then reload (TideSync.swift:22, 25), as the comment at line 21 intends. The only reload call site is TideSync.swift:25 (matches CONTEXT.md:11).
- The provider reads fresh data on every getTimeline and getSnapshot call (TideWidget.swift:15, 19). It does not cache a snapshot in a static or stored property.

## Findings, most likely first

1. Write-then-immediately-reload against cross-process UserDefaults (medium confidence, symptom fit is good)
   - `SharedStore.save` does `defaults.set(data, forKey:)` (SharedStore.swift:21) and returns. `reloadAllTimelines()` runs immediately after (TideSync.swift:25).
   - UserDefaults writes are propagated to the shared preferences daemon asynchronously. The widget extension is a different process, with its own UserDefaults instance, and a freshly spawned extension may run `getTimeline` before the write is visible to it. `load()` then returns the previous snapshot.
   - The widget gets the old value and does not rerun until the next refresh, which matches "a whole refresh behind".
   - Mitigating fact: `defaults` is a computed property (SharedStore.swift:15-17) that builds a new `UserDefaults(suiteName:)` on every access. That does not worsen visibility, but it means nothing in this code forces or awaits a flush.
   - Not verifiable from source: whether this race actually occurs on iOS versions the testers use. Behaviour is OS-dependent and timing-dependent.

2. Widget never self-corrects from the stored data (high confidence, secondary contributor)
   - Policy is `.after(now + 30 min)` (TideWidget.swift:21-22). If the one reload from the app reads stale data (finding 1), or WidgetKit defers the reload, the widget shows old data for up to 30 minutes, and longer because WidgetKit treats `.after` as a hint, not a guarantee.
   - The app never retries the reload. It fires exactly once per `refresh()` (TideSync.swift:25).
   - `reloadAllTimelines()` is also subject to WidgetKit's refresh budget and throttling (cannot be observed from source). Frequent pull-to-refresh in a TestFlight build could hit that.

3. Widget has no staleness or expiry handling (high confidence, but this is a design gap, not the reported bug)
   - The view renders `s.nextHighTide` (TideWidget.swift:32) with no check that it is still in the future, and does not use `fetchedAt` at all.
   - The timeline has a single entry (TideWidget.swift:20). A past tide time will keep showing until the next reload. This can read as "widget is stale" even when the data is consistent.
   - The entry `date` is `.now` (line 20), not tied to the tide time, so there is no scheduled transition at the tide time.

4. Silent failure paths (low to medium confidence, would produce stale rather than one-behind)
   - `try? JSONEncoder().encode` with early return (SharedStore.swift:20) and `try?` decode returning nil (SharedStore.swift:26) swallow all errors. A failed save leaves the old snapshot with no signal. With Double/Date/String fields this is unlikely, but it makes the problem undiagnosable (the testers have no logs).
   - `UserDefaults(suiteName:)!` (SharedStore.swift:16) would crash, not go stale, if the group were unavailable. Notably, it returns non-nil in some mis-provisioned cases, and the process then silently reads and writes a private store.

5. App-side ordering relative to the UI (low confidence)
   - `refresh()` returns the fetched snapshot to the UI (TideSync.swift:26) regardless of whether the persist succeeded. So the app can show new data while the shared store holds old data, which is exactly the reported asymmetry. Not a bug in itself, but it hides persistence failures.
   - The comment at TideSync.swift:17 says refresh also runs "when the app becomes active". The call sites are not in this directory, so the actual trigger frequency cannot be verified.

## Could not verify from source alone
- Whether the App Group capability is actually enabled in the App ID and provisioning profiles for both the app and extension for TestFlight/distribution signing. The entitlements files only declare the id. If the profile lacks the group, the widget would read an empty or private container (likely "Open TideWatch" or never updating, not "one behind", but needs checking).
- Whether SharedStore.swift and TideSync/TideSnapshot are in both targets' Compile Sources (project file absent). The header comment claims it.
- Whether the widget `kind` and the reloaded kinds match. `reloadAllTimelines()` avoids that issue, so this is low risk.
- Actual UserDefaults propagation timing, WidgetKit budget and throttling, and whether the OS delays reloads for background or low-power states.
- How the API's `fetchNextHighTide` behaves (could return the old tide if the server returns the current event; a data-provider issue rather than widget issue). `TideAPI` is only a protocol here.
- Anything about runtime logs: none exist.

## What I would change
1. Remove the dependence on cross-process defaults timing. Prefer a file in the App Group container (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`) written with `.atomic`, or at minimum keep UserDefaults but verify the write before reloading. A cheap and reasonable step is to read back `SharedStore.load()` after save and only then call `reloadAllTimelines()`, and optionally reload again after a short delay.
2. Make the provider robust: build the timeline from the stored snapshot, add entries that expire at/after `nextHighTide`, and use a shorter or snapshot-aware `.after` date. Show a "stale" or "updated at" indicator using `fetchedAt`.
3. Replace `try?` and `!` in SharedStore with logged errors (os.Logger) and a clear fallback, so TestFlight logs can distinguish "not saved" from "not read".
4. Reload only the specific kind (`reloadTimelines(ofKind: "TideWidget")`) after confirming the save.
5. Before changing code, confirm cheaply on a device: log `fetchedAt` in both `refresh()` and the widget's `getTimeline`, and compare. If the widget logs the old `fetchedAt` right after a refresh, finding 1 is confirmed. If it logs the new one but displays old data, look at WidgetKit rendering or caching instead.
