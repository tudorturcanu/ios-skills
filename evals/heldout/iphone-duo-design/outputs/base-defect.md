# Trailnotes iPhone Duo review (base-defect)

## Summary
The layout decision is made once from a global screen size, so it never reacts to the Duo hinge posture. There is a second blocker in Info.plist that would stop the app from filling the inner display at all. Both need to change.

## Findings

### 1. Layout chosen once from `UIScreen.main.bounds` (root cause of the QA complaint)
RootView.swift:7-8:
```swift
// Decided once, when the view is first created.
private let useTwoColumns: Bool = UIScreen.main.bounds.width > 600
```
- This is a stored `let` initialised when `RootView` is created. `body` (lines 10-24) branches on it, so nothing ever re-evaluates it. That matches the symptoms in CONTEXT.md:
  - Launched on the outer display (narrow): it picks the `NavigationStack` branch. Opening the device leaves it there, so you get a stretched single-column list with no detail pane.
  - Launched on the inner display (wide): it picks the `HStack` branch with a fixed `.frame(width: 320)` list. Closing the device leaves it there, so you get a clipped, cramped two-column layout.
  - Relaunch re-creates `RootView` and re-reads the screen, which is why it fixes it.
- `UIScreen.main` is a legacy global singleton. It is deprecated since iOS 16 and has no per-scene or per-window meaning. It also does not give the app's own window size, which matters for split-screen, Stage Manager and the Duo's different displays. Reading it in a property initialiser means it is not reactive even if the value did change.
- The 600pt threshold is an ad hoc device-size guess, not a size class.

### 2. `UIRequiresFullScreen` = true opts out of resizing (Info.plist:11-12)
```xml
<key>UIRequiresFullScreen</key>
<true/>
```
- This key opts the app out of multitasking and flexible window sizing. It is the setting that typically makes an app render letterboxed or in a fixed size on a larger or different display, instead of adapting to the new bounds.
- It will fight any adaptive layout fix. Even with a correct SwiftUI layout, the app may not receive a size change that it can react to on posture change. I cannot confirm exactly how the Duo treats this key from the source alone (see "Could not verify").
- Related: the plist declares no `UILaunchScreen` or storyboard. Missing launch configuration commonly makes an app run in a legacy compatibility size. I mention it as a possible contributor only, not as confirmed.

### 3. Structure is a hand-rolled split instead of an adaptive container (RootView.swift:11-23)
- The two branches are two separate view trees: `HStack` vs `NavigationStack`. Switching between them would also discard identity and navigation state, such as the pushed detail.
- The `HStack` branch hardcodes `.frame(width: 320)` for the list (line 14). On a narrower window than about 320 plus a usable detail width, this clips. This is the "clipped and cramped" symptom.
- In the `HStack` branch `selection` has no push and pop, and in the `NavigationStack` branch it drives `navigationDestination`. `selection` is shared state between both, so it survives a switch, but the presentation differs unpredictably.
- `NavigationSplitView` does this adaptation natively: two columns when wide, collapsing to a stack when compact, and it responds to size changes without custom code.

### 4. Minor points
- `List(notes, selection:)` inside a `NavigationStack` with `navigationDestination(item:)` (lines 20-21) is fine, but selection-based `List` rows do not navigate on their own in a stack on iPhone. It is better to use `NavigationLink(value:)` or let `NavigationSplitView` handle it. I have not verified runtime behaviour.
- `Note.swift:11-12`: `UUID()` in a `static let` is stable per launch, so selection identity is fine. Nothing wrong there.
- TrailnotesApp.swift is a plain `WindowGroup` and has no issue. `UIApplicationSupportsMultipleScenes` is false (Info.plist:8-9), which is fine for a single-window app, but is part of the resizability picture.

## What should change
1. Remove `UIScreen.main.bounds` and the `useTwoColumns` stored property.
2. Preferred: replace the branching with `NavigationSplitView` (sidebar `NoteList`, detail `NoteDetail`), which adapts to the window size automatically and drops the fixed 320 width. If a custom layout is required, use `@Environment(\.horizontalSizeClass)` or a `GeometryReader` or `onGeometryChange` on the actual view's width, and read it in `body`, so it re-evaluates on every size change. Prefer a size class over a numeric threshold.
3. Remove `UIRequiresFullScreen` (or set it to false) in Info.plist so the app can be resized by the system when the Duo opens and closes.
4. Make sure the app has a proper launch screen configuration so it is not run in a legacy size.
5. Keep `selection` in state above the container so the choice survives the switch between one and two columns.
6. Test on the Duo in the closed, half-open and open postures, and also in split-screen.

## Could not verify from source alone
- That `UIRequiresFullScreen` is what prevents the Duo from resizing the window. It is the likely cause, but the exact behaviour depends on the OS and device.
- Whether the Duo reports `UIScreen.main.bounds` as changing on posture change. Either way, the code reads it once, so the defect holds.
- Actual rendering and navigation behaviour of the `List` selection in the stack branch, and the `navigationDestination(item:)` availability, which depends on the deployment target (iOS 17 or later). Info.plist and the project file do not state the target.
- Whether other files exist (assets, project settings, launch screen) that change the picture. Only the four source files and CONTEXT.md were provided.
- Nothing was built or run.
