# Trailhead 4.2.1 (618) crash review (read-only)

## Bottom line
The report shows a main-thread EXC_BAD_ACCESS (SIGSEGV, null-ish pointer 0x10) inside `objc_release`, called from two MapKit frames, called from the app. The crash is NOT in the supplied TrailListViewModel.swift and cannot be tied to any source line from these files. The one dSYM supplied does not match the shipped binary, so the app frames are unresolved. No code change to the view model is justified by this evidence.

## What the report proves (CrashReport.ips)
- Build/OS: Trailhead 4.2.1 (618), iPhone OS 17.4 (21E219), 2026-11-09 19:02:12 +0100.
- Process that exited: Trailhead itself (procName Trailhead; no extension involved).
- Exception: EXC_BAD_ACCESS, codes 0x1, 0x10, KERN_INVALID_ADDRESS at 0x0000000000000010. Termination: namespace SIGNAL, code 11, Segmentation fault. Not a watchdog, jetsam or Swift trap.
- Thread: faultingThread 0 and the only thread has `triggered: true`; queue com.apple.main-thread.
- Fault address 0x10 is a memory address (a small offset from a nil/zero pointer), distinct from the instruction address. It suggests a field access at offset 0x10 on a nil or released/zeroed object.
- Frames (thread 0, top first):
  0. libobjc.A.dylib (image 2) +20412, symbol `objc_release`. Runtime address = 7000000000 + 20412 = 0x1A13BD5BC (computed only, not symbolicated).
  1. MapKit (image 1) +3340288 = 0x19B789D00.
  2. MapKit +3338120 = 0x19B789488.
  3. Trailhead (image 0) +412876 = base 4339253248 (0x102A3C000) + 412876 = 0x102AA0CCC (app caller; unsymbolicated).
  4. Trailhead +90112 = 0x102A52000 (unsymbolicated, outermost).
- Interpretation: a release of an invalid/over-released object occurred inside MapKit code invoked from app code. The release frame is where bad object state surfaced; it does not prove who over-released it. Candidates (hypotheses only): an unbalanced/unsafe-unretained or dangling reference to a MapKit object (annotation, overlay, delegate, view) owned by app code, or a teardown/ordering issue while the Nearby Trails screen is open.
- `lastExceptionBacktrace` is empty, consistent with a signal crash rather than an uncaught NSException.

## What the other files show
- TrailListViewModel.swift: pure Swift, no MapKit, no unsafe/unmanaged/unowned references, no ObjC interop, no threading. `load(from:)` decodes JSON and maps rows (lines 24-27); `makeRow` formats a string and takes `trail.photos.first` (lines 29-32), which is optional-safe, so an empty `photos` array (t-1041 in sample_response.json) yields `thumbnail: nil` and does not trap. Decoding failures throw rather than crash. Nothing here can produce EXC_BAD_ACCESS inside objc_release/MapKit. The empty-photos record in the sample is a red herring for this crash.
- sample_response.json: valid for the `Trail` model (all fields present, `photos` may be empty). It does not contain data that would break decoding.
- CONTEXT.md: reports occur while "Nearby Trails" is open, non-reproducible; this fits a lifetime/race problem but is not proof of one.

## Symbol/dSYM problem (cannot verify)
- Crashed app image UUID: 9A8B7C6D-5555-4666-8777-0123456789AB (arm64), per usedImages.
- dsym_manifest.txt UUID: 5D4C3B2A-9999-4AAA-8BBB-FEDCBA987654 (arm64). These do not match, and the release engineer's note says the archive was re-signed and re-uploaded on 2026-11-08 and the dSYM is from the original archive. The crash (11-09) came from the re-uploaded binary. So this dSYM must not be used: atos with it would give wrong or no symbols. Do not trust any source line mapped through it.
- Also unresolved: system images MapKit (UUID CAFE0001-AAAA-4BBB-8CCC-DDDD00001111) and libobjc (CAFE0002-...) need the iOS 17.4 (21E219) device symbols, which Xcode provides when the device support files are present. MapKit frames 1-2 are therefore not named here.
- Per the guidance, offsets here were computed but not symbolicated (no build/run/symbolicate was done as requested). Note the arch for the app is arm64 and the system frameworks arm64e; resolution must match each slice.

## What to change
- Nothing in TrailListViewModel.swift or the API model should be changed on this evidence.
- Next evidence needed (smallest items that would change the diagnosis):
  1. The dSYM with UUID 9A8B7C6D-5555-4666-8777-0123456789AB (from the re-signed/re-uploaded build, or Xcode Organizer for build 618) so frames 3 and 4 (+412876, +90112) resolve to the app function that calls into MapKit.
  2. iOS 17.4 (21E219) symbols for MapKit frames 1-2.
  3. The Nearby Trails screen's map/annotation/overlay code (the view controller and any MapKit delegate), since the view model is not the caller.
  4. Other crash reports for the same build to see whether the MapKit frames repeat.
- Process fix: preserve the dSYM for the exact shipped binary whenever an archive is re-signed or re-uploaded (confirm UUID with `dwarfdump --uuid`).
- Once the app caller is known, verify with a targeted check, e.g. exercise the Nearby Trails screen while updating/removing annotations or dismissing the screen quickly, with Zombie Objects / Address Sanitizer enabled to catch the over-release. Not run here.

## Not verified
No symbolication, build or run was done. The exact app function and line, the MapKit function, and the cause of the invalid release are unknown. The "dangling/over-released MapKit object" explanation is a hypothesis, not proven. The report is a single user's crash, so frequency is unknown.
