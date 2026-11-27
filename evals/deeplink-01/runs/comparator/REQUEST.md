# Fix lost and duplicated product links

This file is the extracted, synchronous navigation core of an iOS app. Fix RouteCoordinator.swift without changing its public interface or adding dependencies. It can be compiled on this Mac with Foundation; no SwiftUI app, device, or associated-domain hosting is supplied. URL delivery to receive is already confirmed, so focus on parsing and navigation state.

Product contract:

- Accept only HTTPS URLs on shop.example.com, with no explicit port or credentials. Scheme/host matching is case-insensitive. Path must be exactly /products/{id}, with no trailing slash or extra segments.
- IDs contain one or more ASCII letters, digits, underscores, or hyphens. Percent-encoded valid ID characters are accepted after one decode; encoded separators, residual percent escapes, and other characters are rejected. Query and fragment are tracking metadata and do not change route identity.
- Navigate only when both authenticated and ready. A valid incoming link while either condition is false retains intent. The most recent valid link wins. Invalid links must not erase a pending valid link.
- Either ordering of authentication and readiness must work. Consume pending intent once both are true. Repeating the same callbacks must not replay it.
- Delivering the current top destination again does not push another copy. Returning to an older product after visiting a different product is allowed.
- Cancelling login clears pending intent. Logout clears pending intent and navigation history, and ends authentication. Future links after logout may form new pending intent.
- UI readiness can temporarily become false during an authenticated session; incoming routes must wait until it becomes true again.

Make the fix and add your own verification if useful. Report what you actually tested and what these excerpts cannot establish. Do not claim device-level universal-link verification. Do not inspect sibling runs or grading artifacts.
