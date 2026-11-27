# Folio detail open/close memory review

## Verdict
No leak found in the provided files. The growth complaint does not hold on the current build, as far as the files show. Footprint rises from 92 to 121 MB in the first 5 cycles, then stays flat (124, 124, 125, 124 MB through 80 cycles). A leak of 12 full-size decoded images per batch would keep climbing, and this does not.

## Evidence
### Observer lifecycle is balanced
- PhotoDetailViewController.swift:23 registers a handler with `PrefetchCenter.shared.observe`, and the token is stored in `observerToken` (line 6).
- PhotoDetailViewController.swift:30-33 removes that token in `deinit`. PrefetchCenter.swift:22-24 deletes the handler from the `handlers` dictionary.
- The handler closure captures `[weak self]` (PhotoDetailViewController.swift:23). The singleton's `handlers` dictionary therefore does not keep the controller alive. This is the usual leak pattern (a strong self capture in a singleton-held closure), and the code avoids it.
- Nothing else seems to retain the controller. GalleryCoordinator.swift:12-15 creates it and pushes it. The comment on lines 17-18 says no other code holds a reference. The coordinator keeps no property for it, and the pop is the standard navigation one. I could not check the grid code or any other caller, because it was not provided.

### The load path does not retain the controller
- PrefetchCenter.load (lines 26-35) captures `[weak self]` for the PrefetchCenter singleton, which lives for the whole process anyway. It captures `photo`, a value type, and the decoded `image` only until the main-thread block has run.
- It does not capture the controller. After a pop, an in-flight load finishes, calls any remaining handlers and releases the image.
- `handlers` is only touched on the main thread: `observe` (documented as main-thread only), `removeObserver` from `deinit` (main thread for a view controller), and the iteration inside `DispatchQueue.main.async`. I see no data race on the dictionary. The background queue never reads it.
- The dictionary is mutated by `removeObserver` while it is being iterated? No. `handler(...)` runs inside the `for` loop over `handlers.values`, and the handler only sets an image. It does not call `removeObserver`, so there is no re-entrancy problem.

### Footprint data
- footprint.txt shows a one-time rise of about 32 MB (92 to 124 MB) that stays at 124-125 MB from 10 to 80 cycles.
- The simulated memory warning at 80 cycles drops the footprint to 108 MB. That fits reclaimable caches (decoded image caches, allocator or malloc free lists) and not objects that are still referenced. Leaked objects would not be released by a warning.
- The "plateau after ~10 cycles (allocator warm-up)" note in the file is consistent with this reading.

## Minor observations (not leaks)
- `PrefetchCenter.load` has no cancellation and no cache. If the user pops the screen before the load finishes, the file is still read and fully decoded (`preparingForDisplay`) and then discarded. This is wasted work and a transient memory spike, not a growth.
- Every pending load broadcasts to all handlers (line 32) and relies on each handler filtering by `photoID`. This is fine with one detail screen at a time. It scales badly if many observers exist.
- Opening the same photo repeatedly decodes it again every time, because there is no cache. This explains the allocator churn but not unbounded growth.
- CONTEXT.md lines 3-4 appear to have a truncated sentence ("and closing the photo detail screen many times..."). It reads as a text-edit artifact. It does not change the analysis.

## What I could not verify from the files alone
- Whether the controller really deallocates on each pop. That would need a memory graph, an Instruments Leaks or Allocations trace, or a temporary `deinit` log. The source argues it does, but nothing here proves it. The unprovided code that creates `GalleryCoordinator` and the grid view controller could hold references, for example a cache of detail controllers.
- The cause of the 92 to 124 MB step. It could be allocator warm-up, a system image cache, or a one-time cost such as a first-use decode pool. Only a Allocations trace can separate these.
- Only one device (iPhone 13), one OS (17.5) and one photo set were measured, and readings are single-sample. The 124-125 MB variation is within noise, but I cannot say how larger photos, other devices, or low-memory conditions would behave.
- The original report said the app was terminated in the background. No crash log or jetsam report is available. With a flat 124 MB footprint, termination from this pattern seems unlikely on this device. Actual per-device limits are not in the files.
- Whether the earlier "change" that QA mentions was the observer removal and the weak capture. The pre-change code is not provided, so I cannot confirm that this was the fix. I only see that the current code is correct.
- Behaviour of `Photo.url` (file or remote URL). `Data(contentsOf:)` on a remote URL would block a queue thread. That is a performance and not a memory concern here.

## What I would change
Nothing is required to address the growth complaint. Optional hardening:
1. Add a cancellation token or a generation check in `PrefetchCenter.load` so that popped screens do not decode images that nobody will use.
2. Add a small NSCache for decoded images so repeated opens of the same 12 photos do not re-decode. Keep it bounded, because NSCache evicts on memory pressure.
3. Add a `deinit` log or a unit test that asserts the controller deallocates (a weak reference becomes nil after pop), so a future regression such as a strong capture is caught.
4. Capture a single Instruments Allocations trace with generations across about 10 open/close cycles to confirm the controller and image counts return to baseline.
