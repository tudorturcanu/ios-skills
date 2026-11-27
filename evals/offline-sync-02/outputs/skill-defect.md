# Review: duplicate orders from OrderOutbox retry (read-only; nothing edited or run)

Files read: SKILL.md and both of its references (recovery-boundaries.md, diagnostic-cases.md), plus CONTEXT.md, OrderOutbox.swift, FakeServer.swift and OrderOutboxTests.swift in skill-defect.

## Verdict
The client code very plausibly causes the duplicate orders. It treats every thrown error as "not sent" and resends the same non-idempotent `POST /orders` with no operation identity. The skill says not to assume a client retry makes a non-idempotent endpoint safe. CONTEXT.md says the API documents only a JSON body and nothing in the repo describes server-side duplicate handling (CONTEXT.md:3-4). So the server is not known to deduplicate. I cannot prove the production mechanism from this repo, but the code path is a direct match for the complaint.

## Findings

**1. Ambiguous delivery is handled as failure and retried blindly (high).** OrderOutbox.swift:35-42.
- `try await api.post(...)` sits in one `do/catch`. Any error, including `URLError.timedOut` or a dropped connection, goes to the catch at line 39.
- The catch only sleeps 2 s (line 41) and loops. The head item is still `queue.first`, so the identical body is POSTed again.
- A tunnel or train drop can lose the response after the server committed. The client cannot tell "not sent" from "committed but reply lost", so the retry creates a second order.
- This is the "timeout after server commit" boundary in references/diagnostic-cases.md and recovery-boundaries.md.

**2. No operation identifier and no payload binding (high).** OrderOutbox.swift:9-11, 4-5.
- `Pending` holds only `items: [String]`. There is no client-generated ID, account, or state.
- `OrdersAPI.post(path:body:)` has no header or key parameter, so no idempotency key could be sent even if the server supported one.
- The skill requires generating the identity once, persisting it with the immutable payload, and reusing it on retry. It also notes a content hash alone is wrong, because two intentional identical orders (for example two "coffee" orders) would merge.

**3. Duplicate-after-restart window, "committed but not removed" (high).** OrderOutbox.swift:36-38.
- The item is removed and persisted only after the POST returns. If the process dies after the server commits but before line 37-38, the item is reloaded from disk (init, line 21) and re-sent.
- The same applies to a kill while the retry sleep is pending. With no persisted in-flight state, deduplication cannot survive restart.

**4. No pending/in-flight/ambiguous/failed state, and no retry bounds (medium).** OrderOutbox.swift:34-43.
- The queue has no states, so ambiguous outcomes cannot be told apart from untried ones.
- The retry is a fixed 2 s sleep with no backoff, attempt limit, or cancellation check.
- A permanent error such as a 400 or 401 is caught the same way and loops forever, blocking every order behind it (head-of-line blocking).
- Server retry guidance (for example 429 `Retry-After`) is ignored.
- Auth expiry has no handling.

**5. Persistence is silent and non-atomic (medium).** OrderOutbox.swift:46-48 and 21.
- `try? ... .write(to: store)` swallows errors. It is not an atomic write, and there is no file protection option.
- A failed write means `submit` gives no signal that the order is not durable.
- The decode at line 21 uses `try?` with a `?? []` fallback. A corrupt or unreadable store is silently treated as an empty queue, so pending orders are lost.

**6. No account scoping (low to medium, depends on product).** OrderOutbox.swift:9-16.
- There is no account field on queued items. After logout or an account switch, a queued order could be sent under another account, or an in-flight response could affect the wrong store. I could not see the auth layer, so this is a risk, not a confirmed bug.

**7. Reentrancy side note.** OrderOutbox.swift:30-33.
- `flushing` guards concurrent flushes within the actor, so I found no double-flush race there. `submit` spawns an unstructured `Task` (line 27) with no lifecycle control. That is minor.

## Test evidence is misleading (verification gap)
- FakeServer.swift:14-19 already models the failure. In `.commitThenTimeout` it appends the order, then throws on the first call.
- The only test, OrderOutboxTests.swift:4-10, uses the default `.ok` mode (FakeServer.swift:6), so the bug path never runs.
- With `.commitThenTimeout`, the first call commits and times out. The retry runs after 2 s and commits again, giving `committedOrders.count == 2`. I derived this by reading, not by running anything.
- The test name `testQueuedOrderIsSentOnce` implies a guarantee that the code does not provide.
- The fake also accepts the same body twice. It models no ID, so it could not demonstrate dedup even if the client added one.
- The test also does not cover process restart, because it never creates a second `OrderOutbox` on the same store.
- `Task.sleep` real time (2 s) would make a timeout test slow. A controllable clock is needed.

## State table (current behavior)
| Step | Code | State recorded durably |
|---|---|---|
| submit | OrderOutbox.swift:25-26 | item persisted, no ID |
| send | :36 | nothing (no in-flight marker) |
| timeout or any error | :39-41 | nothing, item stays "pending" and is re-sent |
| success | :37-38 | item removed, no acknowledgment record |

## What I could not verify
- Whether the backend deduplicates, honors an idempotency key header, or offers a way to look up an order (reconciliation). CONTEXT.md says the API reference documents only a JSON body. This is the key unknown, and it is the other team's.
- The retention window of any server dedup.
- The real `OrdersAPI` implementation: URLSession configuration, timeouts, status-code mapping, and whether non-2xx responses throw.
- Where `submit` is called, so I cannot confirm a UI double-tap or a second code path. I also cannot see account or auth handling, or whether duplicates come from this queue at all (for example server-side double processing).
- That FakeServer matches production. Its header comment says it mirrors behavior reported by the backend team, but I have no corroboration.
- I ran nothing, so the `count == 2` outcome is reasoning only.

## What I would change, and what I would ask for
Ask the backend team first:
1. Does `POST /orders` support an idempotency key (header or body field)? What are its scope, payload-mismatch behavior, concurrency behavior, and retention?
2. Is there an authoritative lookup by client ID or by user, with consistent visibility, that the client can use to reconcile after an ambiguous failure?

Client changes (do not just add a retry cap or a dedup by content):
1. Make `Pending` carry a persisted `operationID` (UUID generated once at `submit`), account reference, immutable payload, and a state: pending, in-flight/ambiguous, acknowledged, permanent-failure.
2. Persist the in-flight marker before sending. On restart, treat in-flight items as ambiguous, not fresh.
3. Send the ID per the server contract by extending `OrdersAPI`. If the server cannot honor it, add a reconciliation query, or surface an "unconfirmed order" state to the user. Do not auto-resend an ambiguous order.
4. Classify errors: retry only definite transport failures before send. Use bounded backoff with jitter, honor `Retry-After`, and stop on 4xx and auth errors with a user-visible failure and no head-of-line blocking.
5. Make persistence atomic and error-reporting. Fail loudly on a corrupt store rather than defaulting to empty. Scope the queue by account.
6. Handle key lifetime: if the retry happens past the server's dedup window, reconcile or mark unresolved instead of rotating keys.

Regression tests (using the fake transport plus a controllable clock):
- `.commitThenTimeout` then flush: assert exactly one server effect. This fails today.
- Process restart: create a new outbox on the same store after a commit-then-crash, and assert one effect.
- Two intentionally identical orders: assert two effects.
- Permanent 4xx: assert the failure is retained and does not loop or block later orders.
- Make the fake dedupe by key so it can show whether the client reuses the same ID across retries and restarts.

I made no changes. Short of the server answers above, the safest interim mitigation is to stop auto-resending after an ambiguous timeout and show the user an unconfirmed-order state.
