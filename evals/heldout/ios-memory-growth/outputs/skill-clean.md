# Folio detail open/close memory review (source-only)

## Verdict
No ownership defect found in the provided files, and the footprint data shows a plateau, not growth. The complaint does not hold on the current build, within the limits below.

## Evidence

### Measurements (footprint.txt)
Cycles 0/5/10/20/40/80 read 92/121/124/124/125/124 MB. Growth stops after about 10 cycles, and 40 to 80 cycles is flat (125 to 124). A leak of a decoded full-size image per open would keep climbing with 12 identical photos. After a simulated memory warning at 80 cycles the footprint fell to 108 MB, so some of the retained memory is reclaimable (cache-like). This is consistent with bounded warm-up and caching, not unbounded retention. Resident memory alone cannot prove or disprove ownership, so I checked the source path too.

### Ownership path (source)
- GalleryCoordinator.swift:12-15 creates the detail VC and pushes it. It stores no reference to it (comment at lines 17-18). The nav stack drops it on pop.
- PhotoDetailViewController.swift:23-26 registers an observer closure with the singleton PrefetchCenter. The closure captures `[weak self]`, so the singleton's `handlers` dictionary (PrefetchCenter.swift:10) does not retain the controller. This is the usual cycle risk, and it is avoided.
- PhotoDetailViewController.swift:30-33 `deinit` removes the token via `removeObserver` (PrefetchCenter.swift:22-24). It runs on pop, because nothing else retains the VC, and the closure is removed from `handlers`. No handler entry accumulates per cycle.
- PrefetchCenter.load (lines 26-35): the async block captures `self` weakly (the singleton, so irrelevant) and `photo` by value. It holds the decoded `image` only until the main-thread hop completes. The image is not stored in any dictionary, array or cache in PrefetchCenter. After delivery it is owned only by the (soon-deallocated) VC's `imageView`.
- A load that finishes after Back is harmless. The handler is gone, or the VC is deallocated and the weak guard fails. The image is then released.

### Other observations (not causes of the reported growth)
- Several quick open/close cycles can leave overlapping loads in flight (no cancellation). Each decodes and discards, so this adds transient peak memory only. In-flight work is bounded by the number of rapid taps.
- `load` iterates `handlers.values` and calls every handler with every image, each filtered by id. Fine with one or two observers.
- Thread safety: `handlers` is only touched on main (observe in viewDidLoad, removal in deinit, iteration inside the main async block). If a controller's last release ever happened off-main, removal would race. Nothing in the files shows that.

## Not verifiable from the files alone
- What accounts for the roughly 32 MB over the 92 MB grid baseline (about 16 MB remains after the memory warning). It could be the allocator, UIKit/ImageIO caches, or decoded-image buffers. It needs Instruments (Allocations generations, VM Tracker) or the memory graph after dismissal.
- Whether PhotoDetailViewController instances actually reach count 0 after pop (my reading says yes). That needs a persistent-instance count or memory graph check.
- The statement that the app is terminated in the background. Only one device, OS and photo set were measured, so jetsam headroom on low-memory devices and larger photo sets is unknown. Peak during the interaction was not measured either, only idle readings.
- The Photo model, grid code and the rest of the app, which were not provided and may hold other caches.

## What I would change
Nothing is required for a leak. Optional low-risk hardening:
- Make `load` cancellable (or skip when no observer remains) so rapid open/close does not decode unused images.
- Consider downsampling to the display size instead of full-size `preparingForDisplay()` to lower peak and the warm-up level.
- To confirm, capture an Allocations trace over about 10 and 40 cycles, mark generations at the grid after each batch, and verify the PhotoDetailViewController and UIImage counts stay flat after dismissal.
