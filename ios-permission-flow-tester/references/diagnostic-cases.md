# Build framework-specific transition cases

| Scenario | Observe |
| --- | --- |
| First request accepted | Protected operation starts only after authorization resolves |
| First request refused | Screen stays navigable; refusal is not treated as a generic network error |
| Access changed in Settings | Re-entering the app rechecks actual capability and refreshes affected state |
| Partial photo access | Available items remain usable and selection changes are handled |
| Screen dismissed during request | Callback does not resurrect UI or start obsolete work |
| Permission granted but resource unavailable | Error distinguishes missing hardware/service from authorization |
| Photo library denied, system picker opened | Picker remains independently usable; selection transfer is tested separately |
| Authorized library contains no matching items | UI ends loading and displays an empty state |
| Limited selection changes without status enum changing | Asset content refreshes rather than relying only on an authorization-status comparison |

Use only statuses exposed by the particular framework and SDK. Notification authorization and individual settings can differ; location authorization and accuracy are separate dimensions. A common boolean wrapper may discard information needed for correct recovery.

A regression test for Settings recovery should begin with a denied response, transition the fake provider to the permitted status, simulate the relevant lifecycle event, and observe usable UI. Test the real system transition separately; the fake provider cannot establish prompt behavior.
