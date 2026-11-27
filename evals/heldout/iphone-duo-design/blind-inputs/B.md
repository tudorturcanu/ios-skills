# Trailnotes iPhone Duo source review (read-only; nothing built or run)

## Root cause (high confidence)
`RootView.swift:7-8`:
```swift
// Decided once, when the view is first created.
private let useTwoColumns: Bool = UIScreen.main.bounds.width > 600
```
- `UIScreen.main` is deprecated. Its bounds keep the size of the display the app launched on, so the value does not change after fold or unfold. `private let` is evaluated once per `RootView` instance, and `RootView` is created once, in `TrailnotesApp.swift:7`.
- `body` (`RootView.swift:10-24`) branches on this frozen flag. It never reads size classes or any live geometry, so a resize has no way to switch layouts.
- This matches both QA symptoms:
  - Launched on the outer display (compact): `useTwoColumns` is false. After opening, the `NavigationStack` single column stretches across the inner display with no detail pane (lines 19-22).
  - Launched on the inner display: `useTwoColumns` is true. After closing, the `HStack` with a fixed 320 pt list plus a flexible detail pane (lines 12-17) is clipped and cramped on the narrow outer display.
- Relaunching re-evaluates the flag, which is why it fixes the problem.
- Folding is a resize, not a relaunch or life-cycle event. The layout has to be derived from live size, not decided at init.

## Secondary findings
1. **Hand-rolled split layout** (`RootView.swift:12-17`). A fixed `.frame(width: 320)` on a container, and an `HStack` standing in for a split view. This is the "fixed width on a container" case the guidance warns about. It also gives no fold avoidance, balancing or hierarchy handling. It is also a second code path with different state handling: selection is the same `@State`, but one branch uses `navigationDestination` and the other does not.
2. **`UIRequiresFullScreen` = true** (`Info.plist:11-12`). Per the guidance it is honored, but the app still resizes on open/close, so it saves no work and should be dropped. The orientation list (`Info.plist:13-18`) is not itself a bug, but orientation locks are not a fix on the inner display; fix the layout instead.
3. **No toolbar or tab bar exists**, so there is nothing to move to the side bar here. Not a defect.
4. **Selection model.** `selection` lives in `RootView` `@State`. That survives a branch swap because `RootView` itself persists. `NoteDetail` takes `note: Note?`, so a selected note should carry across a layout change once the branching is live. This is the right shape; keep it.
5. **Scene manifest** (`Info.plist:7-10`) contains only `UIApplicationSupportsMultipleScenes`. It is fine for a SwiftUI `App` lifecycle, which uses scenes. I could not verify from source alone that the iOS 27 SDK scene requirement (TN3187) is met by the built product, but SwiftUI `App` normally satisfies it.

## Recommended change
Replace the decide-once flag and the `HStack` with a system adaptive container. Preferred:
```swift
struct RootView: View {
    @State private var selection: Note?
    private let notes = Note.samples
    var body: some View {
        NavigationSplitView {
            NoteList(notes: notes, selection: $selection)
        } detail: {
            NoteDetail(note: selection)
        }
    }
}
```
- `NavigationSplitView` collapses to a stack at compact width and shows two columns at regular width, re-evaluated on every resize. It also handles the fold, and the detail column's bar goes to the side.
- `NoteList` and `NoteDetail` need no change. Remove `UIScreen.main` and the 320 pt frame.
- If a custom branch is kept, drive it from `@Environment(\.horizontalSizeClass)` (`.regular` gives two columns) read inside `body`, not stored at init. Keep `selection` in the model.
- Remove `UIRequiresFullScreen` from `Info.plist` and plan on the app resizing.

## Could not verify from source alone
- Actual behavior on the Duo simulator or device, since I did not build or run anything. The fix is expected, not observed.
- That the inner display in every pose reports a regular horizontal size class, and where `NavigationSplitView` chooses to collapse at the outer width. These depend on iOS 27.1 behavior.
- Whether the project builds with the iOS 27.1 SDK (the deployment settings and `.xcodeproj` are not present). Without that SDK there are no side bars, and the layout will not fill the display.
- Fold and camera reserved-region behavior. The sample is simple enough that the split view should handle it, but this needs testing in the half-folded pose.
- VoiceOver, RTL and Split View behavior.

## Verification to run after the fix
Launch on the outer display, then open: expect two columns with selection kept. Launch on the inner display, then close: expect a single stack. Check the half-folded pose for content in the fold, and the outer, inner portrait and landscape poses. The guidance's other checklist rows, such as Split View and RTL, apply to a fuller app.
