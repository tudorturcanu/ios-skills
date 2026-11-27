# TrailCatalog launch review (source only; nothing built or run)

## Verdict
Build 143 very likely fixes the white/black screen (blank first frame), but the evidence provided does not show that the time until the user sees trails has improved. The 143 numbers cannot support "launch is fixed" in the sense of time-to-content.

## Findings

1. Cause of the 1.8 regression is very likely the 8.5x data growth, with the load on the first-frame path in build 142.
   - Resources/catalog_manifest.json lines 5-6: 6,200 records / 2.15 MB (build 141) to 52,000 records / 18.4 MB (build 142). That matches CONTEXT.md ("more trails") and the jump from about 470 ms to about 2,200 ms (Metrics/cold_launch_timings.json lines 6-10), a ~4.7x increase against 8.5x data. Plausible for read + JSON decode + sort, but the sub-linear scaling is unexplained without a trace.
   - The 142 code is not in the project. That it blocked the first frame is an inference from the symptom and from the comment at CatalogStore.swift:15 ("no I/O or decoding here"), not something I can see.

2. Build 143 does move the work off the main actor.
   - CatalogStore.swift:15: `init() {}` does nothing, so `@StateObject` creation in TrailCatalogApp.swift:5 is cheap.
   - CatalogStore.swift:20-26: `Task.detached(priority: .userInitiated)` does file read, `JSONDecoder.decode([Trail].self)` and sort off the main actor; results are published once on the main actor (lines 27-28).
   - TrailCatalogApp.swift:11 starts `load()` from `.task`, and lines 23/33 show `ProgressView` until `isLoaded`. So the first frame is the placeholder and the main thread is not blocked by decoding. This is sound.

3. The 143 measurement is not comparable to 141/142.
   - Metrics/cold_launch_timings.json line 3 says the placeholder counts as the first rendered frame for build 143. CONTEXT.md line 7 says the same. For 141/142 the endpoint is not stated; it is presumably the list, but that is not documented.
   - The 143 figures (462-501 ms, lines 12-13, 15) therefore measure time to a spinner. The 18 MB read, the decode of 52,000 records and the sort still happen, and they probably still take on the order of 1.5-2 s before any trail appears (this is a guess from the 142 numbers). The user may still wait about 2 s, now looking at a spinner instead of a blank screen. Whether that is acceptable is a product call; it is not "instant like 1.7".
   - A like-for-like comparison would need time to first list content, or a time-to-interactive measurement, for all three builds.

4. The measurement method is coarse and the sample is small.
   - Screen recording with frame counting (line 3) gives roughly 17-33 ms resolution at 60/30 fps and includes tap/launch animation. There are 4 warm-ish samples for 141 and 142 and 6 for 143. The 142 versus 141 gap is large enough to be real; the difference between 141 and 143 (about 10-20 ms) is within noise and is meaningless as a claim, since the endpoints differ anyway.
   - "Cold" is not defined: nothing says the app was force-quit and the device state controlled (reboot, no warm file cache). Run-to-run variance for 142 is small (2145-2302), which suggests consistency, but this does not prove cold state.

5. First launch after install is slow in every build and is not explained.
   - 1,380 ms (141, line 8), 3,650 ms (142, line 11), 1,410 ms (143, line 14). Build 143 first launch is still about 3x the normal launch even though the metric is only the placeholder. Plausible causes: dyld/code-signature verification, uncached app binary, first-run system work. These are guesses; nothing here separates them. If first-launch matters (new users, App Store reviews), it needs a trace, and it is not addressed by the 143 change.

6. Silent failure path in `load()`.
   - CatalogStore.swift:21-24: any missing file, read error or decode error becomes `[]` via `try?`, and lines 27-28 then set `isLoaded = true`. A bad bundled catalog would show an empty list with no error and no log, and could mask a regression (for example a schema change in the bigger file). Worth fixing regardless of performance (return a result/throw and surface an error state).

7. Secondary per-interaction costs that scale with 52,000 rows (not launch, but same data-growth cause).
   - TrailCatalogApp.swift:24: `List(store.search(query))` re-runs the filter on every body evaluation. With a non-empty query (CatalogStore.swift:33) that is up to 52,000 `localizedCaseInsensitiveContains` calls per keystroke on the main thread. That method is relatively slow (locale-aware). Search typing lag is plausible; unmeasured.
   - `search("")` returns the array without copying, so the unfiltered path is cheap. `List` with `Identifiable` rows is lazy, so 52,000 rows are not all built at once. I would not expect the initial render to be the problem, though a large single diff on `isLoaded` flipping is unmeasured.
   - Sorting with `<` on String (line 25) is not locale-aware, so the display order can differ from user expectations; minor.

8. Smaller points.
   - `trails` and `isLoaded` are published separately (lines 27-28); both occur in the same main-actor turn, so SwiftUI should coalesce them. Not a concern.
   - Decoded size: 18.4 MB of JSON becomes many small String allocations; peak memory (data + decoded array) is unmeasured and could matter on low-memory devices. `Data(contentsOf:)` reads the whole file; `.mappedIfSafe` would reduce peak memory.
   - Nothing here shows what the launch screen looks like. If the "white/black screen" is partly the launch storyboard/Info.plist launch screen before SwiftUI draws, that is outside the files given.

## What I could not verify from these files
- The 141 and 142 code (I cannot confirm 142 decoded synchronously in `init` or on the main thread, or what 141 did).
- What the 141/142 timing endpoint was (placeholder, list, or blank frame).
- The contents, field shapes and per-record size of catalog.json (18 MB, not provided), and whether the decode cost is dominated by parsing, sorting or string allocation.
- Where the time actually goes: process start (dyld, static initializers, pre-main), SwiftUI first frame, file I/O, decode, sort, list diff.
- Whether the first-install penalty is OS work or app work.
- Behavior on other devices, OS versions or low-power/thermal states; only one iPhone 12 / iOS 17.5.

## Measurements I would want
1. An Instruments trace on the same iPhone 12 for builds 141, 142 and 143: App Launch template (pre-main vs post-main), Time Profiler for the main thread and the detached task, and os_signpost intervals around read / decode / sort / publish (`xctrace` can record this from the command line). This answers where the 2 s goes and whether the main thread is free during load.
2. A signposted "time to first trail row visible" (and "time to interactive search") for all three builds, with a defined cold-start protocol (force-quit, reboot, N >= 10 runs, report median and spread).
3. The same on a slower or lower-memory device (older iPhone), and peak memory during load (Allocations / memory gauge).
4. Search keystroke latency with the 52,000-row list (Hangs / Time Profiler).
5. A first-launch-after-install trace to explain the 1.4 s / 3.65 s numbers.

## What I would change
Keep the 143 approach (off-main load, trivial init, placeholder). It is the right shape and I see no defect in it for the first-frame problem. Then:
1. Do not call the issue resolved until time-to-content is measured (finding 3). Report both numbers in release notes/QA.
2. If time-to-content is still around 2 s after a trace, reduce it at the source rather than only hiding it: pre-process the catalog at build time into a compact format (binary plist, SQLite/Core Data/SwiftData, or sorted-at-build JSON) so the app does not parse 18 MB and sort 52,000 records on every cold start; or load a first page/screenful quickly and the rest incrementally; or cache a decoded form. Choose after the trace shows whether parse or sort dominates.
3. Replace `try?` with explicit error handling and logging (finding 6).
4. Move search filtering off the per-body-evaluation path: debounce, precompute a lowercased/folded name index, and filter in a task, or use `localizedStandardContains` only if it is measured to be fast enough (finding 7).
5. Consider `Data(contentsOf:options: .mappedIfSafe)` to reduce peak memory.
6. Fix the QA protocol: same endpoint across builds, finer-grained timing (signposts instead of frame counts).

## Files reviewed
- CONTEXT.md
- Metrics/cold_launch_timings.json
- App/TrailCatalogApp.swift
- App/CatalogStore.swift
- Resources/catalog_manifest.json
(all under project/)
