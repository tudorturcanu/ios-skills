# TideWatch widget staleness: read-only source review

Scope: `CONTEXT.md`, `App/TideSync.swift`, `App/SharedStore.swift`, both entitlements files, `Widget/TideWidget.swift`. Nothing was built or run.

## Summary
The source does not show a defect that explains "widget is one refresh behind". The write-then-reload ordering is correct, the App Group id matches in both entitlements, and there is a single widget kind with a single shared key. No fix is justified for the reported symptom from source alone. The staleness has to be located with device evidence (see "Experiments"). There are a few real but secondary weaknesses, listed below.

## Data path (traced)
- Source: `TideAPI.fetchNextHighTide` -> `TideSync.refresh()` (App/TideSync.swift:18-19).
- Durable write: `SharedStore.save` encodes `TideSnapshot` as JSON into `UserDefaults(suiteName: group.com.example.tidewatch)` under key `tide.snapshot.v1` (App/SharedStore.swift:19-22).
- Reload request: `WidgetCenter.shared.reloadAllTimelines()` after the save (TideSync.swift:22-25). Ordering is correct: persist first, then reload.
- Provider read: `getTimeline` calls `SharedStore.load()` and builds one entry (`date: .now`) with policy `.after(+30 min)` (TideWidget.swift:18-23). The provider does not fetch from the network; it only reads the snapshot, so the app is the sole writer.
- Entitlements: both list exactly `group.com.example.tidewatch` (App.entitlements:6-8, Widget.entitlements:6-8), matching `SharedStore.groupID` (SharedStore.swift:12). Single key and single document, so there is no cross-key coherence problem.
- Single widget kind `"TideWidget"`, `StaticConfiguration`, no configuration or account selection (TideWidget.swift:44), so there is no per-configuration or account-mismatch path. `reloadAllTimelines()` covers it.

## Findings

### 1. No ordering or storage bug that explains "one refresh behind" (verified from source)
A reload is requested after a synchronous `defaults.set`. The provider re-reads the key on every `getTimeline`/`getSnapshot`. Nothing in the extension caches the snapshot (no static or singleton cache; `defaults` is a computed property creating a new `UserDefaults` each call, SharedStore.swift:15-17). I found no stale-cache path in the extension source.

### 2. Save failure is silent, yet refresh() still reports success and requests a reload (SharedStore.swift:20, TideSync.swift:22-26)
`try? JSONEncoder().encode` with `guard ... else { return }` swallows an encode failure. `refresh()` then still calls `reloadAllTimelines()` and returns the new snapshot, so the app UI shows the new value while the shared store keeps the old one. This precisely matches "app shows new, widget old". Encoding a `Codable` struct of String/Date/Double is very unlikely to fail, so this is a low-probability cause, but it is the only source path where app and store can diverge. `UserDefaults.set` also returns no error, so the write cannot be confirmed from source.

### 3. Read failure is shown as the "Open TideWatch" placeholder, not as stale data (SharedStore.swift:24-27, TideWidget.swift:35-37)
`try?` decode maps corrupt or schema-mismatched data to nil, and nil renders "Open TideWatch". That is a safe explicit fallback and cannot produce "previous tide time", so it does not explain the report. Note there is no schema version beyond the key suffix `v1`; a future model change would silently blank the widget.

### 4. Widget content ages with no entry for the tide passing (TideWidget.swift:19-22)
The timeline has a single entry at `.now`, then `.after(now+30min)`. The view renders `nextHighTide` as a clock time with no relative or past handling. Once a high tide passes, the widget keeps displaying that past time until the provider reruns (the OS may defer beyond 30 min) AND the app has written a newer snapshot. The provider never fetches, so a widget reload alone cannot advance to the next tide; only an app launch or refresh can. This can read as "it only catches up the next time I refresh" and "a whole refresh behind". This is a design limitation, not a bug in the write path. Predictable changes (a tide time passing) would better live in the timeline, for example by storing several upcoming tides and making one entry per tide, or by fetching in the provider.
Also `fetchedAt` is stored but never used by the view or provider, so staleness is invisible to users and testers.

### 5. Refresh trigger coverage is not visible (TideSync.swift:17, CONTEXT.md:11)
Comments say `refresh()` is called on pull-to-refresh and app activation, and CONTEXT says refresh is triggered only from `TideSync.refresh()`. The callers are not in the provided source, so I cannot confirm that background or other paths do not update the store without reloading. `harbor` is passed into `TideSync` init; the widget has no harbor concept and just reads whatever was last saved (fine for one saved harbor, but a harbor change in the app would only reach the widget on the next successful refresh).

## Not verifiable from source
- Whether `reloadAllTimelines()` results in an observed re-render promptly. Reload requests are budgeted and system-scheduled; a request is not an immediate update, and the widget may re-run late or be throttled, particularly in TestFlight builds on devices with heavy widget use. This is the leading unverifiable hypothesis for the report.
- Whether `SharedStore.swift` is truly compiled into both targets (the comment claims so; target membership is not in the provided files), and whether the provisioning profiles for both targets actually include the App Group (the entitlements files match, but the signed entitlements on the TestFlight build are not visible).
- Cross-process `UserDefaults(suiteName:)` freshness timing on real devices (the extension generally sees committed values on its next read, but I cannot confirm from source).
- Whether `getTimeline` actually runs after each reload and what it reads (no logging exists).
- Who calls `refresh()` and how often; whether the encode or API paths ever fail.
- Behaviour of the displayed widget (rendered timestamps) on any device; no logs were attached.

## What I would change
1. Do not change the write/reload ordering; it is already correct.
2. Add observability first (non-sensitive): a monotonically increasing version or `fetchedAt` written with the snapshot, logged at save, reload request, provider read, and entry creation; optionally show a small "updated HH:mm" in the widget for beta. Mismatch pattern then localizes the boundary: store never updated (finding 2), provider read old version (storage), entry has new version but display old (system scheduling).
3. Make `SharedStore.save` report failure (return Bool or throw), and only call `reloadAllTimelines()` after a confirmed save; surface or log encode failures.
4. Improve timeline design: persist the next few tides and emit one entry per tide time (or past-tide handling), so the widget advances without needing an app refresh; keep a reasonable refresh policy and avoid repeated reload calls as a "fix".
5. Optionally add a schema version and decode-failure logging in `load()`.

## Experiments to run (not done here)
Fresh install with no app launch (expects "Open TideWatch"); app refresh then provider read with version logging; offline refresh; widget on a real device after a refresh, noting versions at each hop; failure injected during save. Distinguish provider unit tests, simulator rendering, and observed device refresh; none of these can be inferred from this source review, and no exact refresh deadline should be promised.
