# Trailhead "Nearby Trails" crash: source review

## Verdict
Most likely cause: an empty `photos` array in the server response. `makeRow(for:)` indexes `trail.photos[0]` without checking, which traps with "Fatal error: Index out of range". The crash report, source and sample response all agree on this, with two caveats below (line-number mismatch and an inconsistent exception address).

## Evidence
- CrashReport.ips metadata: Trailhead 4.2.0 (612), iPhone OS 17.4 (21E219), 2026-11-02 08:14:31 +0100.
- Exception: EXC_BREAKPOINT / SIGTRAP, codes `0x1, 0x00000001029a4c18`. Termination namespace SIGNAL, code 5. This is the process's own Swift runtime trap, not a watchdog, jetsam or an Objective-C exception (`lastExceptionBacktrace` is empty).
- ASI: `libswiftCore.dylib: Fatal error: Index out of range`.
- Faulting thread 0 (`com.apple.main-thread`, marked triggered), top to bottom:
  1. `_assertionFailure` in libswiftCore (imageIndex 1)
  2. `TrailListViewModel.makeRow(for:)` (imageOffset 183320)
  3. `closure #1 in TrailListViewModel.load(from:)`
  4. `TrailListViewModel.load(from:)`
  5. `NearbyTrailsViewController.viewDidLoad()`
- TrailListViewModel.swift:31 is `let thumb = trail.photos[0]`. It is the only array subscript in `makeRow`; line 30 is `String(format:)`, which cannot trap this way.
- sample_response.json: trail `t-1041` "Reinebringen" has `"photos": []` and the next trail has one photo. `Trail.photos` is a non-optional `[URL]` (line 7), so decoding succeeds with an empty array. `load` maps every trail through `makeRow` (line 26), so a single such trail crashes the whole load.
- Chain: the server returns a trail with no photos. `JSONDecoder` accepts it, `makeRow` evaluates `photos[0]` on an empty array, the Swift runtime traps, and the app exits during `viewDidLoad`, which the user sees as quitting to the home screen right after opening the screen.
- This explains why it affects only some users: the data depends on region. The sample is for `lofoten-no`, and the team's own regions presumably have photos for every trail. This is inference. The files show no other region's data.

## Caveats and discrepancies (not verified)
1. Line numbers do not match the supplied source. The report gives `makeRow` at sourceLine 29 and `load` / its closure at 24. In the supplied file, line 29 is the `func makeRow` declaration, 24 is the `func load` declaration, and the subscript is on 31. The shipped build (612) may have been built from a different revision than this file, or the frame lines are function-level. Confirm with the source at the commit for build 612. The function names and the "Index out of range" message still point to this code.
2. The exception address does not fit the images. `0x1029a4c18` is not in the Trailhead image (base `0x102a3c000`, ends `0x102b54000`) or in libswiftCore (base 7000000000 = `0x1a1577...`, 4 MB). Frame 1 (makeRow) computes to `0x102a68c18`, and the libswiftCore frame to `0x1a15774b8`. I cannot reconcile the exception address from these files. It could be a hand-edited or otherwise inconsistent report, or an ASLR/slide difference. It does not change the diagnosis, since the symbol names and ASI message agree.
3. Not verified, by design (read-only review, no symbolication): the image UUIDs (`A1B2C3D4-...` for the app) were not matched to a dSYM and frames were not re-symbolicated. Symbols in the report are used as given. Also not available: any other threads, the app's networking and decoding path, and the actual production payload for this user. The sample is described as the API response for the user's region, but I cannot confirm it is exactly what the app received.
4. `NearbyTrailsViewController` source was not supplied, so how `load(from:)` is called, and whether anything else touches `photos`, is unchecked. Other `photos[0]` uses elsewhere in the app would crash the same way.

## What should change
- Do not index `photos` unconditionally. Either use `trail.photos.first` and make `TrailRow.thumbnail` optional (show a placeholder image), or skip or placeholder trails without photos.
- Decide the product behavior for photo-less trails (show with placeholder versus hide). Keep one bad trail from blocking the list: an empty photo list is valid data and should degrade to a placeholder, not drop the whole screen.
- Check the server contract: is empty `photos` expected? If not, fix the API as well. Client robustness is needed either way.
- Check the rest of the app for similar unchecked indexing of server-provided arrays.

## Suggested verification (not run)
- Unit test: `load(from:)` with the sample JSON (a photo-less trail followed by one with a photo). It should produce two rows and not trap. The current code should fail it before the fix.
- Run the screen against a region or mock whose payload has an empty `photos` list, and confirm no crash and the placeholder shows.
- Rebuild from the revision of build 612 and check that the line numbers and the trapping expression match the report, and symbolicate with the matching dSYM UUID to resolve discrepancy 1 and 2.
