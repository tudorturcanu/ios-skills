# RouteCoordinator fix

Updated `RouteCoordinator.swift` without changing its existing public interface or adding dependencies.

Valid links now replace pending intent, which is consumed only when authentication and UI readiness are both true. Both state callbacks attempt consumption. Pending intent is cleared before top-destination duplicate suppression, preventing replay while allowing a return to an older product after a different destination. Invalid links leave pending intent intact. Login cancellation clears intent; logout also clears history and ends authentication.

Parsing validates HTTPS, the exact host (case-insensitive), absence of credentials and explicit ports, and the exact `/products/{id}` path shape. It decodes only the ID once and checks ASCII letters, digits, underscores, and hyphens. Queries and fragments do not affect identity. Empty port delimiters are rejected as well.

## Actual verification

Environment: Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), arm64-apple-macosx27.0.0.

Ran:

```sh
swiftc -warnings-as-errors RouteCoordinator.swift main.swift -o route-tests
./route-tests
```

Result: **Passed 70 checks**, with successful compilation and no warnings.

The retained `main.swift` executable checks cover:

- Valid IDs, case-insensitive scheme/host, percent-encoded ASCII ID characters, and tracking metadata.
- Invalid schemes/hosts, credentials, explicit ports (including an empty delimiter), malformed path shape, encoded separators, double encoding, percent signs, whitespace, punctuation, Unicode, and invalid UTF-8.
- Both authentication/readiness orderings, newest valid intent winning, invalid links preserving intent, repeated callbacks, repeated current destinations, revisiting older destinations, and temporary UI unreadiness.
- Login cancellation, logout clearing history and pending intent, future intent after logout, and navigation gating while authentication is false.

## Limits

Verification applies to the supplied synchronous Foundation navigation core on this Mac. It does not establish device-level universal-link behavior, associated-domain hosting or entitlements, application event delivery, actual SwiftUI navigation integration, or concurrent/thread-safe access. No iOS app, device, or hosting configuration was supplied or tested.
