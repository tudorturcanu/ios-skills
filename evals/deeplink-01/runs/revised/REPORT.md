# Route coordinator fix

The failing boundaries were parsing and navigation state. URL delivery to `receive` was confirmed by the request; this evaluation did not test OS delivery.

In `RouteCoordinator.swift`, `receive` previously discarded valid links while signed out and appended directly while signed in without checking readiness. Neither prerequisite callback consumed pending intent. The parser previously ignored scheme, authority, extra path segments, and identifier validity. Logout previously left navigation history intact.

The fix preserves the existing public interface and uses Foundation only:

- `receive`, `setReady`, and `setAuthenticated` now use one private consumption helper. A valid link replaces pending intent, and consumption requires both authentication and readiness. Invalid links leave pending intent unchanged.
- Consumption clears pending intent before checking the current top destination. Repeated deliveries do not duplicate the top, but a previously visited product can be revisited after another destination.
- `cancelLogin` clears pending intent. `logOut` also clears pending intent and navigation history and ends authentication. Readiness remains controlled by `setReady`.
- `route(for:)` checks HTTPS and the exact host case-insensitively, excludes credentials and explicit ports (including an empty port delimiter), and requires the exact encoded path structure. Only the ID is decoded once; its bytes must be ASCII letters, digits, underscores, or hyphens. Query and fragment do not contribute to route identity.

## Actual verification

Compiled and executed in this directory using Apple Swift 6.4, target `arm64-apple-macosx27.0.0`:

```sh
swiftc -warnings-as-errors RouteCoordinator.swift main.swift -o route-tests
./route-tests
```

Result: compilation succeeded without warnings; process exited 0 and printed **Passed 69 checks**. `main.swift` contains the executable checks.

| State or behavior | Result |
| --- | --- |
| HTTPS, case-insensitive scheme/host, valid ASCII IDs, encoded valid ID characters | Passed |
| Query/fragment tracking, including duplicate query keys | Passed |
| Unsupported schemes/hosts, credentials, explicit ports | Rejected as expected |
| Empty IDs, trailing/extra/empty path segments, wrong path casing | Rejected as expected |
| Encoded separators, residual escapes, malformed escapes, invalid UTF-8, non-ASCII and unsupported punctuation | Rejected as expected |
| Signed out and unready; authentication first or readiness first | Latest valid intent consumed only after both prerequisites |
| Invalid URL after pending valid links | Valid pending intent retained |
| Repeated prerequisite callbacks and equivalent encoded/tracking URLs | No duplicate navigation |
| Product A → B → A | Revisit allowed |
| Authenticated session temporarily unready | Incoming routes wait; latest valid route consumed on recovery |
| Queued duplicate of current top | Consumed without later replay |
| Authentication lost and restored | Pending intent waits and then navigates |
| Cancelled login | Pending intent cleared; fresh subsequent routes work |
| Logout with history and pending intent | Authentication, history, and pending intent cleared |
| New link following logout | New pending intent retained until authentication returns |
| Terminated/background/foreground iOS delivery, scenes, tabs, sheets, rendered destination | Not tested; no app or device supplied |
| AASA hosting, signed entitlements, CDN association, real tapped universal link | Not tested; no hosting or signed build supplied |
| Product existence and account/resource authorization | Not established by this navigation-only excerpt |

The checks exercise synchronous parsing and state transitions directly. They cannot establish device-level universal-link behavior, UI presentation, asynchronous integration, or concurrent callback safety. No device-level universal-link verification is claimed.
