---
name: ios-offline-sync-review
description: "Review or fix iOS offline caching and synchronization correctness across queued writes, retries, conflicts, process death, and account changes. Use for data consistency work, not basic networking setup."
---

# iOS Offline Sync Review

Trace durable intent from local user action to server acknowledgment and eventual reconciliation.

## Map the contract

Identify the source of truth, cache freshness rules, local database, outbox, server API contract, authentication, and conflict policy. Separate a UI cache from authoritative pending writes. Establish which operations the server supports idempotently and which require a client operation identifier or version precondition. Do not assume a client retry makes a non-idempotent endpoint safe.

Model pending, in-flight, acknowledged, retryable, and permanent-failure states. Inspect atomicity between optimistic local edits and enqueueing. Test what happens if the process dies before sending, after server commit but before acknowledgment, and before removal from the outbox. Deduplication must survive restart when duplicate delivery would corrupt data.

For multi-step actions, record each step's acknowledgment and dependencies. A failed final step does not undo earlier server effects. Check that recovery preserves the failed and unattempted payloads, not merely a draft of the first item. Do not assume a “saved” message proves durable recovery.

## Examine recovery

Review bounded retry/backoff behavior, server retry guidance, cancellation, authorization expiry, and permanent validation errors. Connectivity monitors are hints, not proof that a particular request will succeed. Background execution is opportunistic; correctness must not depend on a timer running while suspended.

Inspect operation ordering, dependencies, tombstones, and pagination/cursor persistence. Do not advance a sync cursor before the corresponding data is durably applied.

For a paginated pull, inject an interruption after applying a page but before saving its cursor. On restart, replay that page and verify that updates and deletions remain correct. Also exercise failure before the page commits and verify that its cursor stays unchanged. If the store supports it, persist the page and cursor in the same transaction.

Define conflicts using server versions or other supported metadata; client wall-clock last-write-wins requires explicit tolerance for clock skew and data loss. Preserve user-visible failed edits or recovery choices.

Scope stored data and queued operations by account. On logout or account switch, prevent old in-flight responses from writing into the new account's store. Choose retention or deletion according to the application's policy rather than silently discarding pending work.

When deduplication uses operation keys, inspect their lifetime, payload binding, and server retention window. Retrying beyond that window may recreate an effect even with the same key. Read [partial completion and retry identity](references/recovery-boundaries.md) for composite actions, draft recovery, or ambiguous delivery.

## Verify

Use a deterministic fake transport and controllable clock when available. Inject timeouts before and after server commit, duplicate responses, reordered completion, expired authentication, rate limits, permanent errors, process restart, and conflicting edits. Assert observable records and server effects rather than internal method call counts. Test offline read behavior and how stale data is communicated.

Return a data-flow/state table, concrete invariant violations with source evidence, fixes if requested, and failure-injection results. Call out server-side guarantees that cannot be verified from the iOS repository.

## Diagnostic cases

Read [diagnostic cases](references/diagnostic-cases.md) when choosing the next experiment or building a regression test. Use the cases that match the observed failure.

## Reference

Consult [URLSession](https://developer.apple.com/documentation/foundation/urlsession) for transport behavior and the actual backend's documented idempotency and conflict contract for application guarantees.
