# Trailnotes iPhone Duo review (project), read-only source review

Files reviewed: CONTEXT.md, Info.plist, TrailnotesApp.swift, Note.swift, RootView.swift. Nothing was built or run.

## Summary
The reported symptom (layout frozen at launch size after open/close) is NOT explained by the Swift code in RootView.swift. That code does react to size changes. The most plausible source-level cause is in Info.plist, where launch-screen/compat configuration is absent, but this cannot be proven from source alone. The Swift layout code also has real robustness problems worth fixing.

## Findings

### 1. RootView does adapt to width changes (contradicts the complaint)
- RootView.swift:8-10: `GeometryReader { proxy in layout(twoColumns: proxy.size.width > 600) }`. GeometryReader re-evaluates whenever its proposed size changes, so if the window actually receives a new size, the layout switches. The "stuck at launch layout" behaviour therefore points to the app not being given the new size (window/scene/compat layer), not to a stale state in this view.
- No use of UIScreen.main, UIDevice idiom, orientation, or any launch-time cached value anywhere in the five files. (Grep-level check by reading; all files are short.)

### 2. Info.plist is the likely culprit (unverified)
- Info.plist:1-18 has no `UILaunchScreen` (or `UILaunchStoryboardName`) key. On iOS, an app without a launch screen declaration is treated as not supporting modern screen sizes and is run in a legacy/letterboxed compatibility mode with a fixed size. On a device whose screen configuration changes (fold/unfold), that would produce exactly "keeps the launch layout / stretched or clipped, fixed by relaunch". I could not verify this against a device or the Duo SDK behaviour from source alone.
- Info.plist:6-10: `UIApplicationSceneManifest` contains only `UIApplicationSupportsMultipleScenes = false`. There is no `UISceneConfigurations`. For a SwiftUI WindowGroup app this is normally acceptable (default config is synthesized), but it is minimal and should be reviewed against what the Duo/resizability guidance expects.
- Info.plist:11-16: supported orientations are Portrait, LandscapeLeft, LandscapeRight only (no PortraitUpsideDown); acceptable on iPhone, but there is no `UIRequiresFullScreen` key either, so that is not the cause. Not a bug, noted for completeness.
- Info.plist lacks `CFBundleIdentifier`, `CFBundleExecutable`, version keys, and the XML lacks a DOCTYPE; likely trimmed for the exercise, not treated as findings.

### 3. Layout decision is a hard-coded width threshold
- RootView.swift:9: `> 600` is a magic number. It is a point width, which is reasonable, but the Duo inner/outer sizes are not known from the source, so I cannot confirm 600 separates them correctly. If the inner display in portrait is near or under 600pt, the app would show the single column on the inner display, matching one of the symptoms.
- RootView.swift:16-21: the two-column branch uses a fixed `.frame(width: 320)` list. At a width just above 600 the detail pane gets about 280pt; at the "clipped and cramped" case this is a hard-coded layout with no minimum-width logic. Fixed widths do not scale.

### 4. Hand-rolled split view instead of NavigationSplitView
- RootView.swift:16-26 re-implements master/detail with HStack vs NavigationStack. The two branches are different view types in an `if/else` (@ViewBuilder, RootView.swift:13), so SwiftUI treats them as distinct identities: crossing the threshold destroys and recreates NoteList (losing scroll position, list selection highlight state, and any in-flight navigation animation). Only `selection` survives because it lives in RootView's @State (RootView.swift:4).
- Recommended: `NavigationSplitView { NoteList } detail: { NoteDetail }`, which collapses and expands automatically by size class/available width, handles the push/pop on compact widths, and preserves selection.

### 5. Detail pane has no navigation container in two-column mode
- RootView.swift:20: `NoteDetail` is placed bare in the HStack. No title, no toolbar, and the compact branch (RootView.swift:23-25) gets a navigation bar but the wide branch does not, so behaviour is inconsistent.
- NoteList (RootView.swift:31-37) has no `navigationTitle`, so the compact stack shows an untitled bar.

### 6. Selection/navigation state interaction across the threshold
- RootView.swift:25: `navigationDestination(item: $selection)`. If the user is in the wide layout with a selection and the window narrows, the new NavigationStack is created with `selection` already non-nil, so it will likely present the destination immediately (unexpected push). Conversely, in the compact layout back-navigating sets selection to nil, which clears the wide detail. Behaviour not verifiable without running; NavigationSplitView handles this natively.
- RootView.swift:35: `List(notes, selection: $selection) { Text($0.title).tag($0) }` works with Hashable Note (Note.swift:3), but in compact NavigationStack a List with selection binding (without NavigationLink) is selection-driven; on iPhone this typically works with `navigationDestination(item:)` but is edge-case territory. Not verified.

### 7. Minor
- Note.swift:10-13: `static let samples` generates new UUIDs per process launch; fine for samples, but ids are not stable (matters if selection is ever persisted/restored).
- TrailnotesApp.swift:5-9: plain WindowGroup; no scene-level size handling needed if the system delivers size changes. Nothing wrong here.
- No Dynamic Type / safe-area handling concerns in this code beyond the above; GeometryReader at root ignores nothing explicitly, and it will fill the safe area region only.

## What could not be verified from source alone
- Whether the Duo's actual width in points for outer/inner display falls on the right sides of 600.
- Whether a missing `UILaunchScreen` actually triggers compatibility-mode sizing for the Duo in the SDK used (this is the leading hypothesis, requires device/simulator check).
- Whether the unstated build settings (project file, deployment target, `UIRequiresFullScreen` in build settings that may inject plist keys, generated Info.plist) differ from this standalone Info.plist. No .xcodeproj was provided.
- Runtime behaviour of the identity-change / immediate-push issue (finding 6).
- Whether `navigationDestination(item:)` requires iOS 17+ and what the deployment target is (not stated).

## What should change
1. Add a `UILaunchScreen` dictionary to Info.plist (empty dict is enough) so the app is not run in legacy size-compat mode; confirm no build setting forces full-screen/compat. Re-test fold/unfold.
2. Replace the GeometryReader + HStack/NavigationStack switch with `NavigationSplitView` (sidebar/list + detail), letting the system decide collapse/expand; remove the fixed 320 width in favour of `navigationSplitViewColumnWidth(min:ideal:max:)`.
3. If a manual threshold is kept, drive it from container width via a size-class or `onGeometryChange`, name the constant, and keep a single stable view hierarchy so state is not rebuilt.
4. Add `navigationTitle` to the list and wrap detail consistently.
5. Test on both Duo displays in both postures, plus a mid-session fold/unfold, to confirm the fix.
