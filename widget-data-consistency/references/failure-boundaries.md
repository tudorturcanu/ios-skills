# Network and account failure boundaries

## Keep useful primary content

Trace acquisition → filtering → optional assets → entry → view. A single outer catch can turn one failed image request into an empty timeline even after posts loaded successfully. Inspect the view before proposing a redesign: it may already render absent images correctly. Confirm which helper the provider calls when private and shared functions have the same name.

Handle optional asset failures per asset, retaining successful content and images. Do not suppress cancellation indiscriminately; check whether the parent operation should terminate, and avoid persisting a cancelled or obsolete result. Separate these regression cases:

| Input | Required distinction |
| --- | --- |
| Successful content, one asset timeout | Preserve content with supported asset fallback |
| Successful zero-item response | Legitimate empty state, including intentional filtering |
| Content transport or decoding error | Failure, not a newly successful empty result |
| Revoked authentication or confirmed account removal | Do not revive account content through stale fallback |

An explicit unavailable state may suffice. Add a last-success snapshot only when the product needs offline continuity; it introduces ownership, expiration, and invalidation work. Key it by account and relevant configuration. Preserve the acquisition time of reused content: timeline activation time is not necessarily fetch time. Do not infer a misleading freshness label where the view displays none.

## Resolve the configured identity

Distinguish a pinned account from an explicit “follow current account” mode. Switching the foreground account does not invalidate a different still-authorized pinned selection. Resolve restored entity IDs to matching entities; suggestions and defaults serve different purposes. Test empty, unknown, and multiple IDs without assuming the framework will select the first returned entity.

A shared singleton is process-local even if its initial values came from an App Group or shared Keychain. Trace how the extension refreshes its authoritative account view. Check the implementation of read helpers: enumeration may hide decoding/access errors, or even perform writes. Reusing a helper that writes back old records can undermine deletion. A storage access failure is not proof that the account was removed.

When a fetch spans account removal, validate account ownership/generation before publishing or persisting its result. A read-check-write sequence alone is not atomic: if a durable cache is introduced, coordinate its commit with invalidation or make obsolete generations unservable. Report surviving-process and server-token assumptions instead of asserting an observed post-logout leak from source alone.

## Follow logout through its callers

Inspect the UI action, ancillary cleanup, durable account mutation, cache invalidation, and reload request. Local removal may be nested inside an optional push-subscription branch or wait behind unbounded remote cleanup. A deletion method existing in isolation does not prove the user's logout action reaches it. Verify durable-operation results rather than equating an in-memory removal with successful storage deletion.

Keep local logout independent of optional remote cleanup, with bounded cleanup behavior appropriate to the app. Request reloads after committed changes. Treat rendered removal and refresh latency as device observations, not guarantees supplied by a reload call.

Apple references: [entity lookup by identifier](https://developer.apple.com/documentation/appintents/entityquery/entities%28for%3A%29) and [widget update scheduling](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).
