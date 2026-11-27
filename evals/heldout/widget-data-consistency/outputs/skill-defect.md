# TideWatch widget staleness: source review (read-only)

## Data path
App `TideSync.refresh()` fetches a snapshot -> `SharedStore.save` writes JSON into App Group UserDefaults -> widget `TideProvider.getTimeline` calls `SharedStore.load()` and builds one entry. The widget does not fetch; it only reads the shared snapshot. Entitlements match in both targets (`App/App.entitlements:5-7`, `Widget/Widget.entitlements:5-7`, group `group.com.example.tidewatch`), and `SharedStore.groupID` (`App/SharedStore.swift:12`) is the same string, so a group mismatch is not the cause from source.

## Primary finding: reload is requested before the durable write (ordering bug)
`App/TideSync.swift:22` calls `WidgetCenter.shared.reloadAllTimelines()` and only afterwards, at line 24, `SharedStore.save(snapshot)`. The skill's rule is to persist a coherent snapshot before requesting a reload. WidgetKit may run `getTimeline` as soon as the reload is requested, so the provider can read the previous snapshot (the app's v7 while the app just fetched v8). The provider then publishes a timeline with the old data and a 30 minute policy (`Widget/TideWidget.swift:19-22`), so the widget stays on the old tide until the next reload. The next pull-to-refresh or app activation triggers another reload, which then reads the snapshot saved by the previous refresh. That matches the "one refresh behind" report exactly.

This is a race, not a guarantee (it depends on when the system schedules the provider run), which fits "sometimes it is a whole refresh behind". Do not rely on sleeps or repeated reloads to paper over it.

Fix: swap the two lines so `SharedStore.save(snapshot)` happens first and `reloadAllTimelines()` after (or `reloadTimelines(ofKind: "TideWidget")`, which is narrower since there is one kind).

## Secondary issues in the same path
1. Write result not checked/durable (`App/SharedStore.swift:19-22`). `save` silently returns if encoding fails (`try?`) and `UserDefaults(suiteName:)!` force-unwraps. `refresh()` returns and reloads even if nothing was stored. UserDefaults writes across processes are cached; `set` is not an atomic, transactional commit visible to another process the instant it returns. Cross-process reads normally see it quickly but this is not documented as immediate. A file written atomically into the container (or a versioned snapshot) would give a clearer guarantee. Not verifiable from source whether this contributes in practice.
2. Decode failure looks like "no data" (`SharedStore.swift:24-27`). `load()` returns nil on both missing and corrupt/schema-mismatched data (`try?`). The widget then shows "Open TideWatch" (`TideWidget.swift:35-37`). Nothing here overwrites good data, which is fine, but a version bump of `TideSnapshot` would be indistinguishable from a first install. The key name `tide.snapshot.v1` hints at versioning but there is no migration path.
3. Timeline never uses the data's own time (`TideWidget.swift:19-22`). The single entry is dated `.now` and the policy is a fixed 30 minutes, regardless of `nextHighTide`. After the tide passes, the widget keeps showing a past "next high tide" until a reload. Predictable changes belong in the timeline: derive an entry date/policy from `nextHighTide` (e.g. refresh after that time), and consider a visible stale state using `fetchedAt`. `fetchedAt` is stored but never used by the widget (no freshness evidence in the UI).
4. The widget never fetches, so when the app is not opened the widget can only show the last saved snapshot. That is a product decision, but beta testers who rarely open the app will see old data; the 30 minute reload only re-reads the same stored value.
5. `refresh()` has no error handling for the failure case besides propagating the throw (correctly leaves the old snapshot and does not reload). The `harbor` is fixed in `TideSync.init`; if the user changes harbor, a reload after the save is also needed, and there is no code here for it. No account/logout or multi-config concerns apply (`StaticConfiguration`, one kind, `.systemSmall` only).

## Not verifiable from source alone
- Whether the race actually occurs on device: it depends on how quickly WidgetKit launches the extension after `reloadAllTimelines()` and the timing of the cross-process defaults propagation. No logs were attached (`CONTEXT.md:8`).
- Actual refresh timing/budget: reload requests and the 30 minute `.after` policy are system-scheduled, so I cannot promise any deadline. A reload request is not an observed widget update.
- Whether TestFlight builds have both entitlements/provisioning profiles correctly signed with the group (only the entitlements files were reviewed, not the profiles or Xcode target settings), and whether `SharedStore.swift` really has membership in both targets as its comment states.
- Whether app-side callers invoke `refresh()` on the paths the report describes (the call sites were not in the provided files).

## Suggested verification
Add timestamps/versions (non-sensitive) at: API result, `save` return, reload request, provider read, entry created, with a unit test using a fake API and fake store asserting `save` occurs before the reload call. Then confirm on device with the extra logging (provider-read `fetchedAt` versus app-saved `fetchedAt`). Rendering/refresh timing needs device observation.

## What I would change
1. Minimal fix: in `TideSync.refresh()`, save first, then reload (`TideSync.swift:22-24`). This is the root cause of the reported symptom.
2. Make `save` report success (throw/return Bool) and only reload after a successful write.
3. Build the timeline from `nextHighTide` rather than a flat 30 minutes, and surface staleness from `fetchedAt` if the design wants one.
4. Optionally distinguish missing vs undecodable snapshots in `load()` for diagnostics.
