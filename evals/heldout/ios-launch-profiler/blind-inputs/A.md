# TrailCatalog cold-launch review (source only, nothing built or run)

## Verdict
The most likely cause is that `CatalogStore.init()` does the full catalog load synchronously on the main thread during app startup. That work is: read the file, JSON-decode it, and sort. The 1.8 catalog is about 8.4x larger than the 1.7 catalog, and the 1.8 cold launch is about 4.6x slower. The evidence is consistent with this but does not prove it. No trace exists, so the cause is a strong hypothesis rather than a measured fact.

## Evidence

### 1. Synchronous heavy work in the initializer (App/CatalogStore.swift:13-20)
- Line 15: `Bundle.main.url(forResource: "catalog", ...)`.
- Line 16: `Data(contentsOf: url)` is a blocking read of the whole file, about 18.4 MB in 1.8.
- Line 17: `JSONDecoder().decode([Trail].self, ...)` decodes about 52,000 records on the calling thread.
- Line 19: `decoded.sorted { $0.name < $1.name }` is an O(n log n) sort. It uses `<` on `String`, which is a Unicode-aware comparison and not cheap. It also sorts by name in code point order, not locale-aware order. That ordering is a behavior point to check before changing the sort.
- The comment on line 14, "so the list is ready immediately", shows the intent. It is also the cause of the problem.

### 2. The initializer runs on the main thread before the first frame (App/TrailCatalogApp.swift:5)
- `@StateObject private var store = CatalogStore()` is in the `App` struct.
- The `App` conformance is main-actor isolated, so this initializer runs on the main thread during scene setup. Nothing in the first window can render until it returns. That matches "white/black screen for a couple of seconds".
- Caveat: `@StateObject` normally takes its initial value lazily through an autoclosure, but for a property declared directly in `App` it is created when the scene is built. In either case it is created before the first list frame. I could not verify the exact point in the launch sequence from the files.
- `CatalogStore` is not annotated `@MainActor`, and no concurrency is used anywhere in the project.

### 3. Failures are silent (CatalogStore.swift:15-18)
- `try?` plus `guard ... else { return }` turns a missing file or a decode error into an empty list with no error and no log.
- This is a robustness issue, not a latency issue. It will matter once loading becomes asynchronous, because the UI will need a loading state and an error state.

### 4. Per-render work in the view (TrailCatalogApp.swift:21, CatalogStore.swift:22-25)
- `List(store.search(query))` calls `search` on every body evaluation.
- With an empty query it returns `trails` (a cheap copy-on-write array). With a query it filters all 52,000 items with `localizedCaseInsensitiveContains` on every keystroke, and it does so on the main thread.
- This is a secondary issue. It does not affect cold launch, but it will affect typing latency in search. Whether it is noticeable on an iPhone 12 needs measurement.
- `Trail` is `Identifiable` with an `Int` id, so row identity is fine. `List` is lazy, so rendering 52,000 rows is not itself the cost on launch, though I cannot confirm that from source alone.

### 5. The timings (Metrics/cold_launch_timings.json) and the manifest (Resources/catalog_manifest.json)
- Manifest: 6,200 records and 2.15 MB in build 141 (1.7); 52,000 records and 18.4 MB in build 142 (1.8). That is 8.4x the records and 8.6x the bytes.
- Build 141, excluding the first launch after install: 470, 455, 512, 480, 462, 491 ms. The mean is about 478 ms.
- Build 142, same exclusion: 2210, 2145, 2302, 2188, 2250, 2176 ms. The mean is about 2,212 ms.
- That is a delta of about 1.73 s, or 4.6x.
- A two-point linear model gives about 243 ms fixed cost plus about 0.038 ms per record. The numbers are plausible for decode plus sort on an iPhone 12 at these sizes. With only two data points, this is illustrative and not a fit.
- If 1.7 had been 100% catalog work, 8.4x would give about 4 s, which is more than observed. So 1.7 already has a fixed launch cost that is not catalog-bound.
- The spread within each build is tight (about 7% for 142). The slowdown is systematic and not noise.
- The first-launch-after-install outliers (1380 ms and 3650 ms) show the same pattern with extra one-time cost. The low-battery run (2890 ms) is a throttled CPU. Both are consistent with a CPU-bound main-thread cause, since they scale it.
- The "more trails" explanation in CONTEXT.md is the only change reported. The data growth and the launch-time growth line up closely.

## What I could not verify from the files
- Where the time goes. File read, JSON decode, sort and first SwiftUI layout are not separated. The decode is my guess at the largest share. The sort and the I/O could be material, particularly on first launch after install.
- Whether the main thread is truly blocked for the whole interval, and what the system's launch watchdog does at those durations. Pre-main (dyld and runtime init) cost is not separated from post-main cost.
- Memory impact. Decoding 52,000 records into structs plus the intermediate `Data` has a peak footprint. I did not estimate it and have no peak-memory figure.
- The real `catalog.json` is not provided, so I cannot check its shape, the actual record size, whether it holds fields `Trail` ignores, or whether it is pretty-printed.
- The QA method is screen-recording frame counting, which includes the system launch animation and has roughly a 17 ms frame granularity. It is good enough for a 1.7 s difference but not for attributing time inside the launch.
- One device, one OS version, 6-7 runs per build, and the "cold" definition is not stated.
- The build configuration (Debug vs Release) used for the QA numbers. Debug `JSONDecoder` is much slower, so Release timings would likely be lower.
- The 1.8 diff beyond the catalog. CONTEXT.md says "believed" nothing else changed. I only have these five files.

## Measurement needed
1. Capture an Instruments trace on the iPhone 12 with a Release build: App Launch template, or Time Profiler plus os_signpost. The `xctrace` guidance describes capturing and reading these from the command line.
2. Add signposts (or `ContinuousClock` logging) around file read, decode, sort, and time-to-first-frame, so the split between read, decode and sort is known.
3. Look at Time Profiler for the main thread between process start and first frame, and expect `JSONDecoder.decode` and `sorted` near the top.
4. Compare with the 1.7 build trace, and with a build of 1.8 where the catalog is truncated to 6,200 records. If launch drops back to about 480 ms, the data size is confirmed as the cause.
5. Record memory (Allocations) and the 1.8 file's actual decode time on the oldest supported device.

## What I would change
1. **Move the catalog load off the main thread and out of `init`.** Make `CatalogStore.init()` trivial. Load in a `.task` on the root view (or a detached task), do the read, decode and sort off the main actor, then publish the result back on the main actor. Show the `NavigationStack` and a progress or placeholder state immediately. This addresses the symptom directly, with the first frame no longer waiting on the catalog.
2. **Add a loading state and surface errors.** Replace `try?` with `do/catch` plus a published `loadError` (and logging), so the empty list from a failed load is distinguishable from an empty catalog.
3. **Stop paying the cost at launch at all, if measurement shows it is still too slow.** Options in increasing effort:
   - Pre-sort the catalog when building the bundle, so the runtime sort goes away (check that code-point order is what the UI wants; if locale-aware order is wanted, sort at build time with the same rule).
   - Switch from JSON to a more compact format (for example a binary plist or a prebuilt SQLite or SwiftData store) and page results.
   - Decode incrementally and show the first screen of rows while the rest loads.
4. **Move search off the render path.** Debounce the query, run the filter off the main thread (or keep a precomputed lowercase name index), and keep the filtered result in state, rather than calling `search` from `body`. Only worth doing after measurement, since it is secondary.
5. Do not change anything else (the view structure, row identity) on the strength of this review. Nothing in the files indicates a problem there.

I would do step 1 and 2 now; they are small and low-risk. Steps 3 and 4 should wait for the trace.
