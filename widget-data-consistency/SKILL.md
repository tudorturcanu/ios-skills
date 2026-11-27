---
name: widget-data-consistency
description: "Diagnose and fix stale or inconsistent WidgetKit content across shared storage, timelines, reload requests, configuration, and account changes. Use for widget data lifecycle issues, not general widget visual design or Live Activities."
---

# Widget Data Consistency

Follow data across process boundaries and distinguish a reload request from an observed widget update.

## Trace the data path

Identify widget kinds/configurations, timeline providers, app intents if used, and data ownership. Establish whether the provider fetches directly, reads a shared snapshot, or combines both before recommending storage changes. For shared data, check entitlements, container URLs, and schema on both targets. The extension cannot rely on the app's in-memory singleton or a continuously running process.

Record timestamps or versions at source update, durable write, reload request, provider read, timeline entry, and displayed result where observable. Avoid logging private widget content. Determine whether stale data originates in the store, provider cache, timeline schedule, or system rendering.

## Inspect consistency

When sharing snapshots, persist a coherent snapshot before requesting a reload. Review atomic file replacement or database transactions, cross-process access, schema compatibility, and decoding failures. Handle missing/corrupt/unavailable protected data with an explicit fallback. Do not interpret a failed read as permission to overwrite good shared data with an empty value.

Separate primary content from optional enrichment: a failed avatar should not erase usable text when the view already supports missing images. Trace the actual called helper and catch boundary. Distinguish successful empty content from failed acquisition; preserve cancellation rather than converting it into ordinary success.

Ensure each configuration reads its own selected account/entity. Explicit account selection need not follow the app's current account. Inspect entity resolution and the complete logout path, including awaited cleanup and storage results. Account logout must clear or invalidate appropriate shared content and request relevant reloads, while acknowledging that already-rendered content may not disappear instantly.

Test an asynchronous timeline fetch that starts for account A and completes after logout or a switch to B. Revalidate the selected account and access before publishing entries or writing a shared cache. Assert that the late result cannot repopulate A’s invalidated content and that B’s entry still reflects B’s data.

Minimize sensitive content and define safe stale states; a reload call is not an immediate privacy guarantee.

Review timeline dates, validity windows, refresh policy, and fallback entries. Predictable changes belong in timelines where practical. Avoid aggressive repeated reloads as a fix: scheduling remains system-controlled. Handle offline and server failure without publishing misleadingly fresh timestamps. Check interactive intent writes use the same consistency rules. When the app already uses WidgetKit push notifications, trace current token registration and invalidation, the APNs request, and the resulting provider read. Check whether the refreshed provider can see the new server data and preserve timeline fallbacks. The system budgets push refreshes. [WidgetKit push notifications](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)

## Verify

Test initial install, no app launch, app write followed by provider read, multiple widget configurations, offline reads, account switch/logout, store migration, and failure during a write. Check small and large families only where their data presentation differs. Preview snapshots do not verify live scheduling; distinguish provider unit tests, simulator rendering, and observed device refresh.

Return the data-flow boundary causing staleness, scoped fix, event/version evidence, and unverified scheduling behavior. Avoid promising exact refresh deadlines that the OS does not guarantee.

## Diagnostic cases

Read [diagnostic cases](references/diagnostic-cases.md) when choosing the next experiment or building a regression test. Use the cases that match the observed failure.

For network-backed providers, entity restoration, or logout defects, read [failure boundaries](references/failure-boundaries.md).

## Reference

Consult [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) for current timeline and reload scheduling behavior.
