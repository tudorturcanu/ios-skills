**Review of the order-queue code against the duplicate-order complaint (read-only; nothing run)**

**Bottom line:** In this repo, the client already does what the documented backend contract needs for duplicate prevention. I found no client-side defect in `OrderOutbox` that explains duplicates after a connection drop. The remaining causes are outside what I can see: the real `OrdersAPI` implementation, or the backend's behaviour. I would not change `OrderOutbox`'s retry logic to chase this.

**Evidence the retry path is idempotent**
- `OrderOutbox.swift:10` generates `operationID` once, when `submit` creates the order. It is stored in the persisted `Pending` struct (`:9-12`, `:26`), so it is reused on every retry and across app relaunches.
- `OrderOutbox.swift:27` persists the queue before the flush starts, so an order is not lost between creation and the first send.
- `OrderOutbox.swift:38` sends `operationID.uuidString` as `idempotencyKey` on every attempt, and the entry is removed only after success (`:39-40`).
- Timeout after the server commits: `catch` (`:42-45`) leaves the item at the head of the queue. The retry reuses the same key, so under the contract in `CONTEXT.md` the server returns the original response and creates no new order.
- A crash after the server commits but before `persist()` at `:40` also reuses the same key on relaunch. That is safe within the 7-day window.
- `OrderOutbox.swift:32-34` sets `flushing` before the first suspension point, so the actor does not run two flushes concurrently. Actor reentrancy is not a duplicate source here.
- `FakeServer.swift:12-21` models the contract correctly: it records the key, commits once, then throws a timeout. `OrderOutboxTests.swift:4-11` covers that scenario.

**What I could not verify**
1. **The real `OrdersAPI` implementation.** It is not in this directory. `OrdersAPI.post` takes `idempotencyKey` (`OrderOutbox.swift:4`), but I cannot see that the production client sends it as the `Idempotency-Key` header. If it ignores the parameter, that would exactly match the complaint. Check this first.
2. **Which contract is current.** The first paragraph of `CONTEXT.md` says the API reference documents `POST /orders` with a JSON body only. The second says v3 accepts `Idempotency-Key`. I cannot tell whether the deployed backend, or the app version the affected customers run, actually honours the header. Nothing in the repo describes server-side duplicate handling.
3. **Server behaviour beyond the contract text.** I do not know:
   - what the server does when the same key arrives while the first request is still in flight;
   - what it does when the same key arrives with a different body;
   - whether a key whose first attempt failed server-side is cached as a failure.
4. **Whether other submit paths exist.** If anything outside `OrderOutbox` creates orders, for example a user re-tapping "Order" or a separate non-queued path, those would carry a different key. I cannot see the callers.
5. **Affected app versions.** I do not know whether the complaints predate this version of the outbox.

**Secondary issues (not causes of duplicates)**
- **Persisted keys expire after 7 days.** An order still queued after more than 7 days would be re-sent with an expired key and could create a duplicate (`OrderOutbox.swift:9-12`, `:38`). There is no created-at timestamp and no expiry handling. This is unlikely to be what the complaint describes.
- **A permanent error blocks the whole queue.** The `catch` at `OrderOutbox.swift:42-45` retries every error forever, including 4xx rejections, and only the head item is ever attempted (`:36`). One bad order blocks all orders behind it, and there is no cap on attempts.
- **A restored queue does not flush on launch.** `init` (`:19-23`) loads the queue but nothing calls `flush()`, so persisted orders wait until the next `submit` or an external `flush()`.
- **Persistence can silently lose orders.** `persist()` (`:49-51`) uses `try?` and a non-atomic `write(to:)`. A crash mid-write could corrupt the file. `init` (`:22`) then falls back to `[]` with no error, so queued orders vanish. This is lost orders rather than duplicates.
- **The test is weak.** `OrderOutboxTests.swift:8-10` does not wait for the `Task` that `submit` starts (`OrderOutbox.swift:28`), so the explicit `flush()` can return immediately through the guard. The test also never checks that retries reuse the same key, and it does not cover relaunch or the crash-before-persist case. It passes mainly because `FakeServer` dedupes on whatever key it receives.

**What I would change or ask for**
1. Ask the owner of the real `OrdersAPI` to confirm the `Idempotency-Key` header is set from the `idempotencyKey` argument. If it is not, that is the fix.
2. Ask the backend team to confirm the header is live in production, plus the three server behaviours in item 3 above. Ask them for server logs for a duplicated order: the two request timestamps, the keys and the responses.
3. Ask support for affected app versions and timestamps, and whether the two orders were created seconds apart (a retry) or minutes apart (a user re-submit).
4. Add tests with a `FakeServer` that records the key on every attempt, asserting the same key is used across retries and across a simulated relaunch (a new `OrderOutbox` on the same store). Also add a test where the first attempt fails before commit.
5. Lower-priority hardening: use atomic writes and surface decode errors, start a flush after `init` when the queue is non-empty, and treat non-retryable 4xx responses as dead-letter instead of retrying forever.
