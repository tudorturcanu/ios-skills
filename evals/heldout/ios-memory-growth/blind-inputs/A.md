# Review: Folio detail-screen memory growth

## Verdict
There is a leak. Every `PhotoDetailViewController` ever pushed is kept alive for the life of the process by `PrefetchCenter.shared`. Nothing removes it, so it survives Back and a memory warning.

## Evidence

1. `PrefetchCenter.swift:10` keeps `handlers: [Handler]` on a process-wide singleton (`:5`).
   `observe` (`:14-16`) only appends to it. There is no remove, unregister or token API anywhere in the file, and handlers are never cleared.

2. `PhotoDetailViewController.swift:23-27` registers a closure on every `viewDidLoad`. The closure uses `self.photo`, `self.currentImage` and `self.imageView` with no `[weak self]`.
   Because `self` is captured strongly, each handler holds its view controller, which holds its view hierarchy, `imageView` and `currentImage`.
   The chain is singleton, then `handlers`, then closure, then VC, then view and image.

3. `GalleryCoordinator.swift:12-15` creates a new VC per tap and pushes it. The comment at `:17-18` says nothing else holds the VC.
   So after the pop, the singleton's handler is the only remaining owner. The coordinator is not the problem.

4. `PhotoDetailViewController.swift` has no `deinit`, `viewDidDisappear` or unregister. The class has no teardown path even in principle.

5. `PrefetchCenter.load` (`PrefetchCenter.swift:18-26`) calls every handler ever registered, on every load (`:23`).
   Stale VCs whose `photo.id` matches the loaded photo (`PhotoDetailViewController.swift:24`) then write the new decoded image into their own `currentImage` and `imageView`. This revives decoded bitmaps into dead screens.
   Per-load work also grows with the number of leaked VCs, so it is O(N) after N cycles.

6. `footprint.txt` is consistent with this:
   - The grid alone idles flat at 92 MB (`:13`), so the grid is not the source.
   - Growth is roughly linear in cycles. The slope is about 4.6 to 5.2 MB per cycle (92 to 118 to 141 to 190 to 287 to 481).
   - A simulated memory warning at 80 cycles gives no meaningful drop (479 MB, `:14`). That fits objects that are strongly referenced rather than purgeable cache.

## What I cannot verify from these files
- Retained size per leaked VC. The code suggests a leaked VC is small (a black view, an `UIImageView`, a reference to an image). Because stale VCs for the same photo id all receive the same latest `UIImage` instance, I would expect decoded-bitmap memory to be bounded at roughly one decoded image per distinct photo, about 12 in total. That would plateau rather than grow linearly to 481 MB.
  The data shows no plateau by 80 cycles. Either the 12 photos are very large and the plateau lies beyond the measured range, or there is more retained per cycle than I can see. The dead-VC handlers also keep the latest images from being freed.
  I cannot tell which from the source alone. Other candidates I cannot rule out are image memory that stays resident per leaked view, or timing where Back is tapped while loads are in flight so that several decoded images are alive at once. This needs a memory graph or an Allocations or VM Tracker run.
- Confirmation that the VC instances are really leaked (instance count of `PhotoDetailViewController` after N cycles). I expect it to equal N, but I have not seen it.
- Photo dimensions, file sizes and decoded size, and what `Photo`/the grid does with images elsewhere. The grid code is not provided.
- Whether the singleton's `handlers` array is ever touched off the main thread. In the provided files, `observe` and the dispatch both run on main, so this is fine as written.
- Whether other leaks exist, such as the grid, a cache or thumbnail code. Only the four provided files were reviewed.

## What I would change
Minimum fix:
- Make the registration removable. `observe` should return a token or `UUID`, and the store should be a dictionary keyed by it with an `unobserve`/`remove` method.
- The VC should hold the token and remove it in `deinit`, and also in `viewDidDisappear` if `isMovingFromParent`.
- Add `[weak self]` in the handler closure. This alone avoids the strong cycle, but dead handlers would still accumulate as empty closures unless they are also removed.

Better design:
- Drop the global observer list. Use a per-request API such as `load(_ photo:, completion:)` or `async func image(for:)`. The VC calls it with `[weak self]` and cancels the `Task` in `deinit` or on disappear. Only the requesting screen receives the image.
- Add an `NSCache` (or equivalent) for decoded images so repeat opens of the same photo do not re-decode. That cache is purgeable on memory warnings, which the current design is not.
- Deliver results on main with a captured value (the `photo.id` check should not read from `self`).

Verification after the fix (not run here):
- Re-run the QA repro and check that footprint is flat after roughly 80 cycles.
- Check in the memory graph that the `PhotoDetailViewController` instance count is 0 or 1.
- Add a `deinit` log or test that asserts the VC is released after the pop.
