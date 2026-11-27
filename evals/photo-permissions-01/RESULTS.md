# Photo permission boundaries: source review and simulator observations

The synthetic app presented the system Photos picker with both undecided and denied PhotoKit read/write access. Add-only authorization remained distinct from read/write access. However, **full-library grant controls failed**: successful `simctl privacy grant photos` commands were followed by `.notDetermined` from the framework. Adding purpose strings or explicitly granting both Photos services did not resolve that discrepancy. The complete simulator suite is not green.

## Executed evidence

[Probe.swift](Probe.swift) is an original UIKit/PhotosUI test app, compiled with Swift 6 mode and warnings as errors. It records actual `PHPhotoLibrary.authorizationStatus(for:)` results and records picker presentation in UIKit's presentation completion. It never calls `requestAuthorization`, fetches PhotoKit assets, saves images, or transfers selected picker items. Each case launches a fresh process; this does not test recovery in a surviving view.

The [runner](reproduce.py) creates its own simulator, targets privacy changes to that device and test bundle, records command output and app observations, then deletes the device and verifies its absence. Existing simulators were not modified. Runtime: iOS 26.3.1, build 23D8133; device type: iPhone 17 Pro; compiler: Apple Swift 6.4. The simulator's default sample photo library appears in screenshots; no personal photo library was used.

| Case | Observed read/write | Observed add-only | Outcome |
| --- | --- | --- | --- |
| Fresh picker | notDetermined | notDetermined | Picker presented; pass |
| Picker after read denial | denied | notDetermined | Picker presented; pass |
| Add-only grant | notDetermined | authorized | Access scopes remain distinct; pass |
| `photos` grant | notDetermined | notDetermined | Expected authorized read/write; fail |
| Both `photos` and `photos-add` granted | notDetermined | authorized | Expected authorized read/write; fail |
| Both scopes revoked | denied | denied | Framework reports denied; pass |

Three runs are retained:

- [Initial run](run/results.json): no usage-description keys; four of five assertions passed. The [frozen runner](run/runner.txt) reproduces that version.
- [Purpose-string check](run-with-purpose-strings/results.json): added read/write and add-only purpose strings; the same four of five assertions passed. Its [runner snapshot](run-with-purpose-strings/runner.txt) is retained.
- [Both-scope check](run-both-scopes/results.json): added the explicit two-service grant case; four of six assertions passed. The current runner matches this run's recorded hash.

The original full-grant expectation was not rewritten to match the unexpected output. These experiments exclude missing purpose strings as a sufficient explanation in this setup, but they do not establish the underlying cause or predict a real user's grant on hardware. No privacy database was edited. All three result files record successful deletion of their newly created simulators.

The parent visually inspected the first run's [fresh picker screenshot](run/fresh_picker.png) and [denied picker screenshot](run/denied_picker.png): both show the picker and its private-access explanation. This supports presentation, not successful item transfer. Apple separately documents that the [system picker displays the library without broad authorization](https://developer.apple.com/documentation/photokit/selecting-photos-and-videos-in-ios).

## Real-app source findings

Read-only inspection used Ice Cubes commit [98098b9](https://github.com/Dimillian/IceCubesApp/tree/98098b9c4b5928f89f338203193c2bf40ab7f38c); [source hashes](source-files.json) pin the two reviewed files. The synthetic probe is not the Ice Cubes app, and none of these app findings were reproduced in its runtime.

1. **Cached status blocks refresh.** In [MediaPickerPanelView lines 192–242](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/StatusKit/Sources/StatusKit/Editor/Components/MediaPickerPanelView.swift#L192), the recent-photos strip snapshots authorization into view state. Its loader returns on cached denied/restricted status before querying the framework. Even calling the method again cannot discover a later grant on that same state instance. The view shows an appearance task, with no explicit foreground refresh in this source. Actual Settings recovery depends on process/view survival; the simulator probe intentionally does not establish that lifecycle behavior.
2. **Empty content means perpetual loading.** Lines 198–205 render progress indicators whenever `assets.isEmpty`. Both denied access and a successful empty fetch leave that array empty. A separate terminal empty/unavailable state is needed; this is independent of whether the system picker can be used.
3. **Authorization is mistaken for completed saving.** In [MediaUIView lines 194–207](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/MediaUI/Sources/MediaUI/MediaUIView.swift#L194), the save helper starts `UIImageWriteToSavedPhotosAlbum` without a completion callback and immediately returns true. The caller displays a saved checkmark at lines 148–163. Apple's [completion contract](https://developer.apple.com/documentation/uikit/uiimagewritetosavedphotosalbum(_:_:_:_:)) supports observing completion and its error asynchronously. No actual save failure was induced here; the verified defect is that the UI success path cannot distinguish it.

Valid behavior matters: the custom strip accepts `.limited` as well as `.authorized`; the adjacent system picker is not gated on that state; and saving queries `.addOnly`. A fix should preserve those distinctions. Automatically replacing the custom strip or demanding broader access for every photo feature would exceed the evidence.

## Skill changes and limits

The permission skill now traces authorization separately from loading and operation completion, routes photo reviews through the three operation boundaries, and requires verifying actual framework status after simulator privacy commands. Its new reference covers stale guards, unchanged limited-status enums with changed asset selections, terminal empty states, and separate evidence for mocks, configured simulator states, prompts, and hardware.

Pre-change instructions are in `inspected-version/`. This was parent-led work, with no independent agent comparison. The app checkout remained unchanged. Real prompt interaction, limited-library selection changes, hardware access, Settings round trips, and actual save/transfer completion remain untested. The revised instructions have not had a comparative behavioral evaluation.

## Reproduce

Use installed, compatible runtime/device identifiers from `xcrun simctl list`. The script creates a new device and output directory; it does not accept an existing device to reset:

```sh
python3 evals/photo-permissions-01/reproduce.py \
  --runtime com.apple.CoreSimulator.SimRuntime.iOS-26-3 \
  --device-type com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  --usage-descriptions \
  --output /tmp/photo-permission-results
```

The retained run exits **1** because grant assertions failed, even though cleanup succeeded. Retain and investigate discrepancies on other runtimes rather than assuming this environment's results are universal. `xcrun simctl help privacy` itself warns that assigned permissions can bypass normal usage-description requirements and that changes may terminate an app.
