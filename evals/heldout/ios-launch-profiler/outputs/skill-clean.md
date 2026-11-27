# TrailCatalog launch review (read-only, source only)

Nothing was built, run, traced or modified. The skill's helper script was not used, because the supplied samples are not in its format and conditions do not match (see below). Everything here is a hypothesis from source plus QA's screen-recording numbers, not a trace result.

## Bottom line

Build 143's `CatalogStore` already defers and offloads the catalog work. That plausibly fixes the *blank screen* symptom, but the supplied timings do not show that the user waits less for a usable list. The metric measures the wrong endpoint for the complaint, and the build 143 numbers are labelled placeholders.

## Findings

1. **The 143 timings are not evidence of a fix.**
   - Metrics/cold_launch_timings.json line 3 says build 143 counts are "placeholder counts". Lines 12-15 (and 16) are therefore not real measurements and must not be reported as results.
   - The "ms" interval is "tap to first rendered frame" (CONTEXT.md line 7). In 143 the first frame is the `ProgressView("Loading trails")` (TrailCatalogApp.swift lines 32-34), because `init() {}` does no work (CatalogStore.swift line 15).
   - So ~480 ms for 143 matches 141 only because both draw a frame early. It says nothing about when the list appears and accepts a tap/scroll/search.
   - The user complaint ("sits on a white/black screen for a couple of seconds") is about a blank screen. A visible spinner for the same ~2 s would fix the blank-screen wording but not the underlying delay to a usable list.

2. **Likely true cause of the 1.8 regression (hypothesis).**
   - The manifest (Resources/catalog_manifest.json lines 6-7) shows records grew from 6,200 (2.15 MB) to 52,000 (18.4 MB), about 8.4x records and 8.6x bytes. 142's first-frame time rose from ~470 to ~2,200 ms. That is a delta of ~1.7 s, roughly 8x the 141 post-launch cost if 141 loaded synchronously.
   - Consistent with a synchronous read+decode+sort on the main thread before first frame in 142. But the 142 source is not provided, so this is inferred from the timing shape only. Needs a trace to confirm.
   - First-launch-after-install runs show the same pattern (1380 vs 3650) with an extra ~0.9 to 1.4 s that is not explained by catalog size alone. That points to install-time effects (cold file cache, code-signature/page-in, first-run work). These are separate samples and must be reported separately; 143's first-install 1410 ms is a placeholder.

3. **Time to usable list in 143 is probably still on the order of seconds (hypothesis, unmeasured).**
   - `load()` (CatalogStore.swift lines 17-29) reads an 18.4 MB file, JSON-decodes 52,000 records, and sorts them, all inside one detached task. That work is merely moved off the main thread, not reduced. Expect it to take about as long as the old main-thread version, since it is serial, CPU-bound work (possibly faster or slower at `.userInitiated` with thermal/QoS effects). The user still sees a spinner for that duration.
   - Skill guidance: a change that improves first frame but delays usability "may have moved latency rather than improved usability". Nothing in the project measures the readiness endpoint.
   - After the task completes, the main actor does `trails = result` (line 27) and the `List` renders. `search(query)` (line 32-33) is called from `body` and filters up to 52k items on the main thread per keystroke/re-render with `localizedCaseInsensitiveContains`. That is potentially slow typing. Unmeasured.

4. **Correctness / robustness issues in `load()` that affect the readiness story.**
   - Lines 21-24: any failure (missing file, I/O, decode error) is swallowed via `try?` and returns `[]`; then `isLoaded = true` (line 28). A decode failure would show an empty list and no error or retry, and a guard on `isLoaded` (line 18) would prevent re-loading. This would also make timing look "fast" if decoding fails early, so a timing run should verify the row count.
   - The `guard !isLoaded` check is not an in-flight guard. If `.task` fires twice (scene recreation, view identity change), two concurrent 18 MB decodes can start. Minor, but worth a Task handle or `isLoading` flag.
   - Line 25: `$0.name < $1.name` is a non-localized sort (differs from the localized search and from user-expected ordering for accents). Behavior, not performance, but worth noting if the sort is moved.
   - `Data(contentsOf:)` (line 22) reads the entire file into memory; with 18 MB plus 52k decoded structs, peak memory is notable on older devices. `.mappedIfSafe` would reduce I/O copying. Unmeasured.
   - `.task` is attached to the root view inside `WindowGroup` (TrailCatalogApp.swift line 11), so it runs when the view appears, not before. That is fine, but the load starts only after first scene render.

5. **Sample quality in the timings file.**
   - Method is a 60 fps-ish frame count from a screen recording, so resolution is ~16-17 ms, and it includes the system launch animation. It is not an Instruments/MetricKit/XCTest interval.
   - Sample counts: 141 has 4 steady + 1 first-install; 142 has 4 + 1; 143 has 6 + 1 (all placeholder). One sample per first-install condition, so no spread can be stated there.
   - Debugger attachment, build configuration (Release vs Debug), thermal state, background app state, and data state are not recorded. Do not label these "cold" without cache definition.
   - Steady-state spread looks tight (141: 455-512 ms; 142: 2145-2302 ms), so the 141 vs 142 gap is large relative to noise. That comparison is credible as a first-frame result; the 143 one is not.

## What I could not verify from the files

- Where 142's time actually went (main-thread decode? file read? sort? SwiftUI layout of 52k rows?). 142 source is absent; catalog.json is absent.
- Whether 143's list becomes usable in ~2 s, less, or more. Whether the detached task competes with launch work.
- Whether first frame in 143 is really ~480 ms (the numbers are placeholders).
- Cost of `search()` per keystroke at 52k records, and `List` behavior with 52k rows.
- Peak memory during load; whether the first-install overhead is page-in, signing, or something else.

## Measurements needed

1. Release build on the iPhone 12 (iOS 17.5), no debugger, with the Xcode/Instruments version recorded. Record 5-10 steady launches plus separately labelled first-after-install launches for builds 141, 142, 143.
2. Add `os_signpost` (or `OSSignposter`) intervals: app init -> first frame (placeholder drawn), `load()` start -> file read done -> decode done -> sort done -> `isLoaded = true` -> list first rendered -> list accepts scroll/search. Capture both endpoints from the same launch. Keep Organizer/first-draw metrics separate from this app-defined readiness.
3. Instruments Time Profiler plus System Trace (or App Launch template) to attribute main-thread vs background CPU, I/O waits and QoS delays; for 142, check for main-thread decode before first frame.
4. Time `search("a")`-style queries at 52k records.
5. Verify the loaded row count equals 52,000 on every run.

## What I would change

Do not ship 1.8.1 on these numbers alone. First capture the readiness measurement above. If time-to-list is still ~2 s, then:

- Reduce the work rather than relocating it: ship a pre-sorted, compact format (binary/plist/SQLite or pre-indexed) instead of an 18 MB JSON decoded at launch; or paginate/stream, e.g. decode the first screenful first, or query a database lazily. Pre-sort at build time to drop the runtime sort.
- Use `Data(contentsOf:options: .mappedIfSafe)`, and decode with a streaming or chunked approach if JSON must stay.
- Debounce search and filter off the main thread (or precompute a lowercase index) once the catalog is large.
- Replace `try?` with explicit error handling and a visible error/retry state; add an in-flight guard.
- Keep the loading placeholder (it is the correct visible state) and report both "first frame" and "list usable" as separate metrics in the QA sheet; relabel the 143 rows as real measurements only after they are captured.

If measurement shows time-to-usable is already acceptable, the 143 change is sufficient and only the robustness items above remain.
