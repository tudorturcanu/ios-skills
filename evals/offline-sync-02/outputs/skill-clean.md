## Summary

I found no defect in `OrderOutbox` that explains duplicate orders after a connection drop, assuming the backend contract in CONTEXT.md lines 6-7 is true and the real transport actually sends the key. The retry path reuses one persisted key per logical order. The most likely explanations are outside the reviewed files: a real transport that drops the header, a second retry layer, UI double-submit, or a retry past the 7-day window. I read all files in the skill folder (SKILL.md and both references) and in skill-clean. I edited, created and ran nothing.

## Contract inconsistency in CONTEXT.md

CONTEXT.md lines 3-4 say the API reference documents `POST /orders` with a JSON body only, and that nothing in the repo describes duplicate handling. Lines 6-7 then say v3 accepts `Idempotency-Key` and honors it for 7 days. I treated the second paragraph as the working contract, but it should be confirmed with the backend team. The 7-day key retention is the only evidence for the dedupe guarantee. The skill says not to assume a client retry makes a non-idempotent POST safe.

## Data-flow and state table

| Stage | Evidence | State |
| --- | --- | --- |
| Create | `OrderOutbox.swift:25-27` appends `Pending(operationID: UUID(), items:)` once and calls `persist()` | pending, durable if the write succeeds |
| Send | `:38` posts with `first.operationID.uuidString` as the key | in-flight; there is no separate in-flight marker |
| Ambiguous failure (timeout, tunnel) | `:42-45` catches every error, sleeps with backoff (1s doubling to 60s), loops with the same head item and key | retryable |
| Ack | `:39-40` calls `removeFirst()` then `persist()` | acknowledged and removed |
| Restart | `:22` reloads the queue, and `operationID` is `Codable` (`:10`) | the key survives restart |

Failure-point reasoning (by reading only, nothing was run):
- **Commit then lost response, in-process:** the same key is retried, so the server dedupes. This is correct.
- **Process death after server commit but before `persist()` at `:40`:** the item reloads with the same key and is re-posted. The server dedupes it within 7 days.
- **Per-attempt keys:** not present. `operationID` is generated once at `:26`.

## Findings

1. **Retry beyond the 7-day dedupe window is not handled (`OrderOutbox.swift:36-46`).** There is no creation timestamp in `Pending` (`:9-12`) and no expiry or reconciliation path. If an order commits but is never acknowledged, and the outbox is retried after the window (a long outage, a dead process, or a reinstall that keeps the store), the same key could create a second order. This is unlikely for tunnel or train drops, so it is not the main suspect, but the contract bound is real. Severity: low for this complaint.

2. **Unbounded retry with no error classification (`:42-45`).**
   - Every error is treated as retryable. That includes 4xx validation errors, 401 or expired auth, and 429 (`Retry-After` is ignored).
   - A permanent error on the head item blocks the whole queue forever (head-of-line blocking).
   - There is no failed state and no user-visible recovery.
   - If the flush `Task` is cancelled, `try? await Task.sleep` (`:43`) returns immediately, so the loop would spin with no delay.
   - This does not cause duplicates, but it causes stuck or lost orders and battery drain.

3. **Persistence is fragile (`:22`, `:50`).**
   - `persist()` uses `try?`, so write failures are silent.
   - `write(to:)` is not `.atomic`, so a crash mid-write can leave a corrupt file.
   - The init decode also uses `try?` with a `?? []` fallback, so a corrupt file silently empties the queue and drops all pending orders.
   - `submit` (`:25-29`) has no way to report that persistence failed. The user may believe an order is queued when it is not.

4. **No account scoping (`:9-17`).** `Pending` has no account ID, there is one shared store file, and nothing prevents an in-flight response from a previous account from being applied after logout or account switch. The auth token is not in the payload, which is good, but it is also not tied to the item. Whether to retain or delete pending orders on logout is a product decision I could not determine.

5. **No flush on launch (`:19-23`).** `init` loads the queue but does not start `flush()`. Pending orders after a restart are sent only if some caller invokes `flush()` or `submit()`. I could not see the callers.

6. **Duplicate user intent is not guarded (`:25-27`).** Each `submit` creates a new key, so two identical taps (or a retry by the UI layer after a "failed" state) produce two distinct operations and two orders. That would match "two identical orders" in the support report. Nothing in this repo suppresses it.

7. **Tests do not prove the claim.**
   - `OrderOutboxTests.swift:4-11` is racy. `submit` fires an unstructured `Task { flush() }` (`OrderOutbox.swift:28`). The test's own `flush()` may return at the `flushing` guard (`:32`) and assert at once.
   - It does not cover restart, key reuse across restart, expiry, permanent errors, or an ack arriving then a persist failure.
   - With a fresh key per attempt it may fail or pass depending on scheduling, so it is a weak regression test.
   - `FakeServer.swift:12-21` ignores `path`, does not model the 7-day expiry, payload mismatch, or concurrent requests, and times out only once. It just assumes the contract.

## What I could not verify

- The real `OrdersAPI` implementation. It is not in the repo, so I cannot confirm that the `Idempotency-Key` header is actually sent, that URLSession-level or other retries do not reuse or rotate keys, or that timeouts and redirects are handled.
- The server's real behavior: the retention window, payload-mismatch behavior, concurrent-request behavior, and whether the key is scoped per account.
- Callers of `submit` and `flush`: UI double-tap protection, launch-time flush, and logout handling.
- Whether the support cases actually involve this queue, and the time gap between the original and duplicate order. A duplicate seconds or minutes apart points to a missing header, a second retry layer, or UI double-submit. A gap near or over 7 days points to expiry.
- No failure injection was run. All conclusions come from reading the code.

## What I would change or ask for

Ask for:
- the production transport code, or a captured request showing the header on the wire;
- server logs for a duplicated order pair (keys, timestamps, client versions);
- backend confirmation of the key contract in item 1;
- whether the real flow has any other retry layer.

Change, in priority order:
1. Add a deterministic fake transport and tests for these cases: timeout after commit, process restart with the same key, ack followed by a persist failure, and expiry.
2. Classify errors into retryable, permanent, and auth. Honor `Retry-After`, cap retries, add a persisted failed state with user recovery, and stop head-of-line blocking.
3. Store `createdAt` and the account ID in `Pending`, and define the behavior after the 7-day window (reconcile or surface as unresolved instead of silently re-posting).
4. Make persistence atomic and make errors visible. Do not wipe the queue on a decode failure.
5. Start `flush()` after init, and guard against double-submits at the UI or intent level.
