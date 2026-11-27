# Trailhead "Nearby Trails" crash: source review (read-only)

## Verdict
Most likely cause: an unguarded `trail.photos[0]` on an empty array in `TrailListViewModel.makeRow(for:)`, TrailListViewModel.swift:31. The crash report and the sample response both point to it. This fits "only some users": it only happens in regions where at least one trail has `"photos": []`.

## Evidence
- CrashReport.ips: `EXC_BREAKPOINT` / `SIGTRAP`, termination "Trace/BPT trap: 5". This is how a Swift runtime trap shows up.
- CrashReport.ips, `asi`: `"Fatal error: Index out of range"`. This is the Swift array-subscript bounds-check message.
- CrashReport.ips, thread 0 (main thread, `com.apple.main-thread`), top to bottom:
  - `_assertionFailure` in libswiftCore
  - `TrailListViewModel.makeRow(for:)`
  - `closure #1 in TrailListViewModel.load(from:)`
  - `TrailListViewModel.load(from:)`
  - `NearbyTrailsViewController.viewDidLoad()`
  - This matches the "quits right after opening the screen" report. The load happens synchronously in `viewDidLoad`.
- TrailListViewModel.swift:31: `let thumb = trail.photos[0]`.
  - `photos` is a non-optional `[URL]` (line 7), and nothing checks that it is non-empty.
  - `makeRow` is the only subscript in the file.
  - It is called from the `map` at line 26, so one bad trail aborts the whole load.
- sample_response.json: the first trail, `t-1041` "Reinebringen" (region `lofoten-no`), has `"photos": []`. The second trail has one photo.
  - Decoding succeeds: an empty array is valid for `[URL]`, so there is no decode error.
  - The first trail is processed first, so `[0]` on an empty array traps there.
- The crash timestamp, 2026-11-02 +0100, is a European time zone. That is consistent with the sample being the user's region, but it is not proof of it.

## Why it is intermittent
It depends on the server data. Users whose region returns every trail with at least one photo never hit it. Users whose region has a trail with no photos crash on every open of the screen, which is why the team cannot reproduce it. The crash is not device- or OS-specific.

## What should change
1. Don't force a photo to exist in `makeRow`. Pick one of these:
   - Make `TrailRow.thumbnail` optional, use `trail.photos.first`, and show a placeholder image in the UI.
   - Use `trail.photos.first ?? placeholderURL`.
   - Skip trails with no photos, using `compactMap` and returning `nil`. This hides trails from users, so it is probably the wrong choice for a hiking app.
2. Check whether other code assumes a non-empty `photos` array or a thumbnail. This is not in the files provided.
3. Add a unit test that loads `sample_response.json` and expects two rows.
4. Ask the backend team whether an empty `photos` array is intended. The client should be tolerant either way.

## What I could not verify from these files
- Line numbers do not match the source. The crash report says `makeRow` is at line 29 and the closure and `load` at line 24. In the provided file, the subscript is on line 31, the closure on line 26, and `load` starts at line 24. Line 29 is the declaration line of `makeRow`.
  - Frames can be attributed to a function's start line.
  - Or the source differs slightly from build 612 (4.2.0). I can't confirm either, so I can't prove this file is the exact shipped source.
- The `exception.codes` crash address (`0x1029a4c18`) does not fall inside the Trailhead image listed in `usedImages`.
  - The image is base 4339253248 (0x102708000), size 1146880, so it ends at 0x102820000.
  - The frame offsets are consistent, so this may just be a sanitized or hand-edited report.
  - The report is unsymbolicated and I did not symbolicate it. I am relying on the symbols and line info already in it.
- I can't confirm that the reporting user's actual server response matches `sample_response.json`. It is described as the response "for that user's region", and it contains exactly the trigger.
- `NearbyTrailsViewController` is not provided. I can't tell how it calls `load(from:)`, or whether it has other issues. There is also no networking code, so I can't check how errors are handled.
- Only one crash report was provided, so I can't tell whether all affected users share this crash.
- I did not build or run anything.
