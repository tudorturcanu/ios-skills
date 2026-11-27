# TrailCatalog cold-launch review (source only, no build/run, no trace)

Applied the ios-launch-profiler guidance: read-only, so everything below is a hypothesis grounded in source and QA numbers, not a profile. I did not run the guidance's comparison script (instructed not to run anything); the medians below were computed by hand from the JSON.

## What the supplied measurements do and do not show

Source: Metrics/cold_launch_timings.json (iPhone 12, iOS 17.5, screen recording, frame count from tap to first rendered list frame).

| Cohort | n | Samples (ms) | Median | Range |
| --- | --- | --- | --- | --- |
| build 141, steady launches | 6 | 455, 462, 470, 480, 491, 512 | 475 | 455-512 |
| build 142, steady launches | 6 | 2145, 2176, 2188, 2210, 2250, 2302 | ~2199 | 2145-2302 |
| build 141, first launch after install | 1 | 1380 | n/a | n/a |
| build 142, first launch after install | 1 | 3650 | n/a | n/a |
| build 142, low battery mode | 1 | 2890 | n/a | n/a |

- The regression is real relative to the noise: about +1.7 s, roughly 4.6x, and the ranges do not overlap at all. Fine for a "something got much slower" conclusion, even with small n.
- The first-install and low-power-mode rows are single samples and differ from the steady cohort in conditions. I kept them out of the medians; they are not comparable and not enough to estimate anything. Low-power mode in particular is a confounder (CPU throttling), so 2890 should not be read as noise.
- Missing condition data: build configuration (Debug vs Release), debugger attachment, thermal state, network, data state (fresh vs upgraded), whether 141 and 142 were installed identically. If either build was a Debug or debugger-attached build, the numbers would be inflated. Unknown, so no equivalence assumed.
- Interval: "tap to first rendered list frame". This includes the system launch animation and OS-side launch work, and has ~16 ms (60 fps) granularity. It is not a pre-main / init / first-draw breakdown, and there is no separate "ready to interact" endpoint. Here first frame and readiness coincide only because the list is not drawn until the data is loaded (see below).
- Nobody has an Instruments trace (CONTEXT.md line 7), so no time has been attributed to any function.

## Source evidence (candidate critical path)

1. App/TrailCatalogApp.swift:5 `@StateObject private var store = CatalogStore()`. The autoclosure runs `CatalogStore.init()` on the main thread when the App/scene body is first evaluated, before `TrailListView` can be built or drawn.
2. App/CatalogStore.swift:15-17 inside `init()`: `Bundle.main.url`, `Data(contentsOf:)` (synchronous read of the whole file), and `JSONDecoder().decode([Trail].self, ...)`, all synchronous, all in the initializer. Line 19 then sorts the whole array (`sorted { $0.name < $1.name }`). Line 14's comment states the intent: "ready immediately", i.e. deliberately blocking.
3. Resources/catalog_manifest.json: build 141 had 6,200 records / 2.15 MB; build 142 has 52,000 records / 18.4 MB (about 8.4x records, 8.6x bytes). CONTEXT.md line 5 says "more trails" was the only believed change. The slowdown is about 4.6x for an 8.4x data increase, which is directionally consistent with cost that scales with catalog size on a path that has a sizeable fixed floor (~450 ms for process launch, scene setup and first render). That fits, but is not proof: it is a correlation between two numbers, not an attribution.
4. TrailCatalogApp.swift:21 `List(store.search(query))` computes from all 52k trails; with an empty query it returns the array (cheap), so first render is probably not dominated by this, but the first list layout of a 52k-row collection is unmeasured.

Hypothesis (unverified): the ~1.7 s is main-thread file read + JSON decode of 52k objects + sort, executed before the first frame, so the user sees the launch screen / blank window until it finishes. Plausible split between read, decode and sort is unknown; JSON decoding is usually the largest of these but that is not established here.

## Things in the source worth noting but not shown to affect launch

- CatalogStore.swift:15-18 uses `try?` and `guard ... else { return }`. If the file is missing or decode fails (e.g. one malformed record among 52k), the app silently shows an empty list with no error. Correctness/diagnosability issue; also means a failure would look "fast".
- CatalogStore.swift:24 `localizedCaseInsensitiveContains` over 52k names on every keystroke, synchronously on the main thread during body evaluation. This is a probable search-typing hitch, not a launch problem. Not measured.
- CatalogStore.swift:19 sorts with `<` (non-localized ordering), so accented/mixed-case names may order oddly. Minor and unrelated to the complaint.
- `CatalogStore` is not `@MainActor`; moving the load off-main requires care with `@Published` mutations.

## What I could not verify from the files

- Where the time goes (read vs decode vs sort vs first list layout vs pre-main). Needs an Instruments Time Profiler / App Launch trace (or `xctrace`) of a release-like build on the iPhone 12, with signposts around `CatalogStore.init` read, decode, sort, and first list appearance. Also check whether the main thread is on CPU (decode) vs waiting on I/O.
- The cause of the extra ~900 ms (141) and ~1450 ms (142) on first launch after install. Source does not explain it; candidates include cold file cache, first-launch system work and signature validation of a larger bundle. Needs separate first-install traces; do not fold into steady-state.
- Whether the 141 vs 142 difference includes anything other than catalog size (CONTEXT says "believed" nothing else changed). The catalog.json itself (18 MB) is not provided, so record shape, nesting and per-record size cannot be checked. Diffing the two builds' binaries/dependencies/Info.plist would rule out other causes.
- Build configuration and debugger state of the QA runs.
- Frame-count precision: counted from screen recordings; interval start (tap) vs process start differs from `MXAppLaunchMetric` / Organizer first-draw, so keep those separate.

## What I would change (after confirming with a trace)

Do not apply before measuring; the trace could show that something else dominates.

1. Take the load off the launch path: initialize `CatalogStore` empty and cheap, then load in an async task (`.task` on the list view or a detached/background task), decoding off the main thread and assigning `trails` once on the main actor. Show an explicit loading state so the first frame appears quickly.
2. Because moving work only shifts latency, measure two intervals from the same launch: tap to first frame, and tap to "list populated and accepting selection" (signpost end after assignment and first list render). The second is the user-facing readiness; it may not improve much unless the work itself shrinks.
3. Reduce the work itself if the trace shows decode dominates: precompute sorted order at build time (avoid runtime sort); use a cheaper format (SQLite/ Core Data/ binary plist or pre-indexed store) with paged or on-demand fetching rather than materializing 52k structs; or decode incrementally and show the first page quickly.
4. Move search filtering off the main thread/debounce it if typing is shown to hitch (separate experiment).
5. Replace `try?` with logged error handling so failures are visible.
6. Regression guard: an XCTest launch metric plus a signposted "catalog ready" metric tracked per build, with the catalog size noted.

Validate each change individually with repeated runs under the same conditions (release build, no debugger, same device state, ideally 10+ steady launches per variant), report distributions, and separately check first-install, offline startup, and the first tap/search after launch to ensure the deferred load did not just move the delay to the first interaction.

## Conclusion

Strong circumstantial evidence (blocking synchronous read+decode+sort in a `@StateObject` initializer, plus an 8.6x larger bundled catalog and a non-overlapping 4.6x slowdown) points at catalog loading on the main thread before first render. This is a hypothesis supported by timing correlation and code structure, not a measured attribution; confirm with a trace before changing code.
