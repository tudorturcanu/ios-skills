# Folio detail-screen memory growth: source review

## Verdict
There is a clear ownership defect. `PhotoDetailViewController` is retained forever by the `PrefetchCenter.shared` singleton through a never-removed, strongly self-capturing handler. Every open/close leaks one controller (plus its loaded view hierarchy and whatever image it currently holds). The source is consistent with footprint.txt, but I could not confirm the retention or the size of each leak without a memory graph or Allocations trace.

## Evidence (ownership path)
Singleton -> `PrefetchCenter.handlers` -> closure -> `PhotoDetailViewController` -> `imageView` / `currentImage`.

- PhotoDetailViewController.swift:23-27: `PrefetchCenter.shared.observe { ... self.photo.id ... self.currentImage = image; self.imageView.image = image }`. The closure uses `self` strongly, with no `[weak self]` capture.
- PrefetchCenter.swift:10 and 14-16: `handlers` is a plain array on a process-wide singleton (line 5: `static let shared`). `observe` only appends. There is no remove or unsubscribe API, no token, and no cancellation anywhere in the file.
- PhotoDetailViewController.swift has no `deinit`, `viewDidDisappear` or `isMovingFromParent` cleanup. GalleryCoordinator.swift:12-15 only pushes. Its comment at lines 17-18 says nothing else references the controller. That is true, which is the point: the pop would free it, except the singleton's closure still holds it.
- `observe` is called from `viewDidLoad`, so each push adds one permanent handler and pins one controller.

Because the handler list is never pruned, handlers also pile up and are all invoked on every load (PrefetchCenter.swift:23). Cost per image delivery therefore grows linearly with the number of past opens. Each stale handler filters by `photoID`, but stale controllers for the same photo id pass the guard and are updated. Stale controllers for the same photo therefore keep receiving and holding the newest decoded image.

## Fit with footprint.txt
- Growth is almost exactly linear, about 4.8-5.2 MB per cycle (26 MB over 5 cycles, 97 MB over 20 to 40, 194 MB over 40 to 80). That matches a per-open leak rather than a bounded cache, which would plateau. With "same 12 photos", a cache keyed by photo would level off after the first pass.
- The grid alone idles flat at 92 MB for 10 minutes, so the growth is tied to the detail flow.
- The memory warning at 80 cycles gave no drop (481 to 479 MB). Nothing in the source responds to warnings, and the retained controllers are strongly held, so nothing can be purged.
- Background termination is the expected end state of this growth (jetsam).

## Open questions I cannot resolve from the files
1. **Per-cycle size.** About 5 MB per cycle is larger than a bare controller plus an empty view. Because every retained controller for a photo id is overwritten with the newest image, the number of distinct live decoded images should be bounded (at most around 12 plus in-flight). A bounded image set would not give linear growth on its own. So either (a) a cycle covers more than one open (CONTEXT.md is ambiguous about this), (b) the retained controllers and views account for more than I assume, or (c) other allocations are involved: layer backing stores, a `preparingForDisplay()` result, or `Data` buffers that are not obviously released. I cannot tell which from the source. Allocations generations and a memory graph would show which types grow per cycle.
2. Whether `UIImage` instances are shared across retained controllers as I reasoned (each handler receives the same `image` object) rather than copied. I believe they are shared. A memory graph would confirm it.
3. There is no trace or memory graph, so the retention path is inferred from the code and not observed. The linear fit is also based on only six readings from a single device and build.
4. Other contributors that cannot be ruled out here: image loading and caching in code I was not given, such as the grid and the `Photo` source. Only three source files were provided.
5. Whether the 4.8 MB per cycle is peak or settled footprint. QA readings were taken at the grid screen, which is the right settled point, but there was no warm-up cycle and no record of the idle wait.

## Secondary issues in the same code
- `load(_:)` is fire-and-forget (PrefetchCenter.swift:18-25). If the user taps Back before decode finishes, the work still completes and the callback runs. Because of the leak, the callback finds the dead controller still alive and updates it. After a fix, the callback must tolerate the controller being gone.
- `self` is captured strongly in the `queue.async` and `DispatchQueue.main.async` blocks (PrefetchCenter.swift:19, 22). This is only transient, not a leak, because the singleton is immortal.
- No image cache or memory-warning handling exists. That is acceptable, but loading is not deduplicated.
- `handlers` is mutated from the main thread (`viewDidLoad`) and read on main (line 23), so there is no data race on it as written. That depends on callers staying on main.

## What I would change
1. Give `observe` an unsubscribe mechanism, either a token-returning registration (`observe(...) -> Token`, with `remove(_:)`) or a per-photo completion API. Replace the global broadcast with a per-request completion, `load(photo) { image in ... }`. That removes both the leak and the O(N) fan-out.
2. In the controller, capture `[weak self]` and unregister on teardown, in `deinit` and/or `viewDidDisappear` when `isMovingFromParent`. Cancel or ignore pending loads when the screen is gone.
3. Optionally keep a bounded `NSCache` of decoded images in `PrefetchCenter` so reopening the same 12 photos is cheap without growing.
4. Verify by running the same 12-photo repro. Record the build, device, data set and an idle point. Warm up once. Then compare surviving `PhotoDetailViewController` counts (Allocations generations or memory graph) and footprint at 0, 20, 40 and 80 cycles after the change. Expect the count to stay at zero (or near zero) after dismissal and the footprint to plateau. If footprint still rises with zero surviving controllers, look at decoded image buffers and caches.
