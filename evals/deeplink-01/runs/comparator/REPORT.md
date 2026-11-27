# RouteCoordinator verification

Implemented the requested fix in `RouteCoordinator.swift`, preserving the existing interface and Foundation-only dependencies.

- Valid links replace pending intent. Navigation drains it only when authenticated and ready; either callback order works, and consumed intent is cleared before duplicate suppression.
- Only the current top destination is deduplicated. A previously visited product can be pushed again after another destination.
- Login cancellation clears pending intent. Logout additionally clears the navigation history and authentication. Readiness remains controlled by `setReady(_:)`.
- Parsing requires HTTPS and the exact case-insensitive shop host, without credentials or an explicit port (including an empty port delimiter). It validates the encoded path structure before decoding the ID exactly once and requiring nonempty ASCII letters, digits, underscores, or hyphens. Query and fragment do not affect route identity.

## Actual verification

Used Apple Swift 6.4 (swiftlang-6.4.0.34.1), targeting arm64-apple-macosx27.0.0:

```sh
swiftc -warnings-as-errors -swift-version 6 RouteCoordinator.swift Verification.swift -o verification
./verification
```

Compilation succeeded with warnings treated as errors. The executable reported **Passed 67 assertions**. The retained `Verification.swift` covers accepted case variations and encoded ID characters; tracking metadata; rejected schemes, hosts, ports, credentials, malformed path shapes, encoded separators, repeated encoding, non-ASCII and invalid characters; both callback orders; latest-valid intent preservation across invalid input; repeated callbacks; top duplicate suppression and revisits; readiness suspension; cancellation; logout; and fresh links after logout.

## Limits

This verifies the supplied synchronous Foundation navigation core on the available Mac compiler. Calls are assumed to be serialized; the unchanged interface does not establish thread or actor isolation. No SwiftUI application, navigation destination registration, device, application lifecycle integration, associated-domain entitlement, or hosted association file was available. Device-level universal-link delivery and UI navigation have not been verified.
