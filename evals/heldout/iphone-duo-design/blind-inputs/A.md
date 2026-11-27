# Trailnotes iPhone Duo source review (read-only)

Files reviewed: `CONTEXT.md`, `Info.plist`, `TrailnotesApp.swift`, `Note.swift`, `RootView.swift`. guidance audit script (`audit_duo_readiness.sh -q`) reported no common anti-patterns, so it did not flag anything below. I did not build or run anything.

## Symptom
The app keeps its launch-time layout when the device opens or closes. Relaunching fixes it.

## Main finding: the code does not explain the "stuck layout" by itself
`RootView.swift:8-10` wraps everything in a `GeometryReader` and switches on `proxy.size.width > 600`. A GeometryReader re-evaluates when the window resizes, and `@State selection` (line 4) lives above the branch. So by source alone, folding/unfolding should re-run `layout(twoColumns:)`. A stuck layout therefore points to the app not actually being resized by the system, and the likely source-visible cause is configuration, not RootView logic.

### Likely cause (strong suspect, not confirmable from source): missing launch screen in Info.plist
`Info.plist:3-18` has no `UILaunchScreen` dictionary (and no `UILaunchStoryboardName`). iOS treats an app with no launch screen declaration as not supporting modern/arbitrary screen sizes and runs it in a compatibility (scaled/letterboxed) presentation with a fixed size. That would give exactly the reported behaviour: the app keeps its launch-time geometry across display changes, and relaunch picks up the new display. Fix: add `UILaunchScreen` (an empty dict is enough). Needs verification on a Duo simulator/device, and I cannot see the Xcode project (build settings, SDK, `INFOPLIST_KEY_*` generated keys), which may supply this key. If the project generates the plist (`INFOPLIST_KEY_UILaunchScreen_Generation = YES`), this one is a non-issue.

### Related config to verify (cannot be seen from these files)
- SDK: the guidance requires an iOS 27.1 or later SDK. Apps built with iOS 26 sit centered at their old size with empty space around them; 27.0 builds get no side bars. The SDK is a build setting, not in the provided files.
- No `UIRequiresFullScreen` in `Info.plist` (good). Orientations (lines 11-16) include portrait and both landscapes, so no orientation lock problem. Upside-down is absent, which is fine on iPhone.
- Scene manifest (`Info.plist:7-10`) is minimal and `TrailnotesApp.swift` uses `WindowGroup`, so the SwiftUI scene life cycle is in use; no TN3187 launch blocker. Verify that no `UIScreen.main` or AppDelegate-only setup exists elsewhere (not in the supplied files).

## Code issues in RootView.swift (these matter even once resizing works)
1. **Hand-rolled responsive switch (lines 8-9).** `proxy.size.width > 600` is a magic device-width threshold instead of size classes. The guidance says to size from size classes and system containers (`horizontalSizeClass`), not fixed widths. Replace the whole branch with `NavigationSplitView` (adapts compact vs regular automatically, balances columns around the fold, puts the detail column's bar on the side).
2. **Hard-coded `.frame(width: 320)` (line 18).** Fixed sidebar width; also the likely source of "clipped and cramped" if the window is narrower than expected while still in the two-column branch (for example when the system keeps the old inner-display size, or in Split View). It ignores fold and camera reserved regions.
3. **Two different view trees (lines 15-26).** HStack branch vs NavigationStack branch means the list and detail views are destroyed and rebuilt on every width change. `selection` survives because the state is in RootView, but scroll position, any draft text, and navigation push state do not. The guidance requires outer -> inner -> outer to keep selection, draft and scroll anchor. Also, going compact with a non-nil `selection` immediately pushes the detail (line 25), which may or may not be wanted; a split view handles this natively.
4. **No fold handling.** The custom HStack puts a 320 pt list and a detail view without reading `reservedRegions(kind: .division)`. When partially folded (book pose), text or the divider can land on the fold. A `NavigationSplitView` (or `ArrangementView`) is the system way to get this for free. Even columns are not an issue here (no grid).
5. **No toolbar / navigation title / side-bar surface.** There are no `.toolbar` items at all, and the two-column branch has no `NavigationStack` or split view, so nothing can ever move to the side on the Duo. If the app has actions (new note, delete, share) they are not in the supplied files; if added, use `.toolbar` with `Label` title+symbol items inside the navigation container, with a `.topBarPinnedTrailing` primary action.
6. **Detail pane shows plain `Text` (line 42) with `.padding()` only.** Inset comes from padding, not safe-area/layout margins; on the outer display the outer camera region and in landscape the side bar are not considered. Using standard containers handles this.
7. **Minor:** `NoteList` uses `List(notes, selection:)` with `.tag($0)` on `Text` (line 35). With `List(notes, selection:)` on an `Identifiable` collection the tag is redundant but harmless; the selection type is `Note?` with a `Hashable` Note, which works. `notes` is a static sample (`Note.swift:10-13`), irrelevant to the bug.

## Recommended changes
- `Info.plist`: add `UILaunchScreen` (empty dict) if the project does not generate it; confirm SDK is iOS 27.1+.
- `RootView.swift`: replace GeometryReader + HStack/NavigationStack with a single `NavigationSplitView`:
  ```swift
  NavigationSplitView {
      NoteList(notes: notes, selection: $selection)
          .navigationTitle("Notes")
  } detail: {
      NoteDetail(note: selection)
  }
  ```
  (Use `NavigationSplitViewVisibility`/`.navigationSplitViewColumnWidth` only if a custom width is needed, no fixed 320 frame.) This gives compact single-column push, regular two-column, fold-aware balancing, and a stable view identity across resizes.
- Give the detail a scrollable container and use safe-area-aware padding.
- If a main/secondary arrangement with tabletop behaviour is wanted, `ArrangementView` inside the `NavigationStack`, with navigation around it.

## What I could not verify from source alone
- Whether the Xcode project generates a launch screen key or sets `UIRequiresFullScreen` / other plist keys via build settings.
- The SDK the app is built with (iOS 27.1+ needed for correct Duo behaviour).
- Actual point widths of the Duo outer and inner displays and whether the app is being given a scaled compatibility window (my main hypothesis) versus a real resize.
- Behaviour in each pose (closed, open, partially folded, Split View, RTL), inner camera and Live Activity overlap, and VoiceOver. Those require the Duo simulator or a device.
- Whether the observed symptom could also come from a different mechanism elsewhere in the project (no other source files were supplied).
