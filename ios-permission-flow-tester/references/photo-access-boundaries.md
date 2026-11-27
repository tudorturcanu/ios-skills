# Photo access boundaries

## Map operations, not a single Photos permission

| Operation | Review boundary |
| --- | --- |
| Select items through `PhotosPicker` or `PHPickerViewController` | The system picker can present without broad PhotoKit authorization. Do not gate it on the app's library-read permission. Test transfer of selected data separately from presentation. |
| Enumerate assets in a custom recent-photos strip | Query `.readWrite`; handle both authorized and limited access according to the feature. Picker access does not authorize arbitrary asset fetches. |
| Save a newly generated image | Request the access required by the chosen saving API; do not demand library reading solely to add an item. Check the actual asynchronous save result. |

These operations may coexist in one screen. A custom strip requiring authorization does not imply the adjacent system picker needs that authorization. Conversely, selecting through the picker does not grant the custom strip access to every asset.

Consult Apple's [picker sample](https://developer.apple.com/documentation/photokit/selecting-photos-and-videos-in-ios) and [access-level query](https://developer.apple.com/documentation/photos/phphotolibrary/authorizationstatus%28for%3A%29). Check purpose strings for the actual protected operations in the built target; a picker-only path is not a reason to introduce an unnecessary access request.

## Reconcile capability and content state

A status initialized in view state is a snapshot. A method that returns early based on cached denial before calling the framework cannot discover a later grant, even if the method is invoked again. Query current capability before such guards and refresh at an appropriate lifecycle or action boundary. A plain appearance `.task` does not establish that a surviving view refreshes after a Settings round trip; verify the actual event path.

Retest both directions: denied → authorized and authorized/limited → denied or changed selection. Track whether the process and view survived; a cold relaunch can hide stale-state bugs. When limited selection changes, the enum may still be `.limited`, so status equality alone cannot prove the asset list is current. Use relevant library changes or explicit refresh according to the feature.

Keep loading, empty success, unavailable access, and operation failure distinct. `assets.isEmpty` is not a loading flag: a denied library or an authorized empty fetch can remain empty indefinitely. Show an appropriate terminal state while leaving independent picker/file-import alternatives usable. Restricted access may be outside the user's control; do not promise that visiting Settings can remove it.

## Match tests to what they establish

Mocked authorization transitions exercise the app's state handling. Simulator-assigned permission tests exercise configured states on that runtime. Real prompt interaction verifies request timing and purpose strings. Hardware tests cover camera availability and device-specific behavior. Report these separately.

Use an explicit disposable simulator identifier and test bundle when changing privacy state. Consult `xcrun simctl help privacy` rather than assuming every framework state has a CLI equivalent. Verify the framework's observed status after a grant/revoke/reset; if it differs, record an environment/setup discrepancy instead of relabeling the test as passed. Do not directly edit the privacy database to force an expected result.
