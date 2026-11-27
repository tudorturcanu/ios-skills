## Verdict
The duplicate-order complaint is explained by the code. Every retry resends the same request with nothing the server could use to recognise it as a repeat. I could not confirm the server-side half of the story, so the fix needs the backend team.

Files reviewed, all read in full: `CONTEXT.md`, `OrderOutbox.swift`, `FakeServer.swift`, `OrderOutboxTests.swift`. Nothing was edited, built or run.

## Main finding: retries are not idempotent (`OrderOutbox.swift`)
- `Pending` (lines 9-11) holds only `items: [String]`. No order ID or idempotency key is ever created or stored.
- `flush()` (lines 34-43) calls `api.post(path: "/orders", body: first.items)`. On any thrown error it sleeps 2 seconds and loops, resending the same body. The `catch` at lines 39-42 does not distinguish "request never reached the server" from "server committed, response lost".
- The tunnel or train drop is the second case. The server creates the order, the response is lost, the client sees a timeout and posts again, and the server cannot tell it is a repeat. Result: two identical orders.
- `FakeServer.swift` lines 14-19 models this exactly. In `.commitThenTimeout` mode it appends to `committedOrders` and then throws `URLError(.timedOut)` once. The next retry commits again, so the server ends up with two copies.
- `OrdersAPI.post(path:body:)` (lines 3-5) has no parameter for a key or header, so the protocol itself cannot carry one.

## Related defects in the same code
1. **Crash or kill window (lines 36-38).** If the app dies after the server commits but before `queue.removeFirst()` and `persist()`, the order stays on disk. It is resent on the next launch, with the same duplicate result. A stable per-order ID would fix this too.
2. **Non-atomic, silent persistence.** `persist()` (line 47) uses `try?` and a plain `write(to:)` with no `.atomic` option. A failed or partial write is swallowed. In `init` (line 21), a decode failure also becomes `[]`, so a corrupt file silently drops every queued order.
3. **Blind retry of every error (lines 39-42).** A permanent failure, such as a 4xx for a bad payload, is retried forever. The head-of-line order blocks everything behind it, and the 2-second sleep has no backoff, cap or attempt limit. The loop also never checks for task cancellation.
4. **Racy flush.** `submit` (line 27) starts an unstructured `Task { await flush() }`. The `flushing` guard (line 31) makes a second concurrent `flush()` return immediately, even though the first is still mid-post. Callers cannot rely on `await flush()` meaning "the queue is drained".
5. **Concurrent outbox instances.** I saw no cross-instance guard on the `store` file. Two `OrderOutbox` instances on the same file, for example from an app extension, could send the same orders twice.

## Test coverage gap (`OrderOutboxTests.swift`)
- The single test, `testQueuedOrderIsSentOnce` (lines 4-10), uses `FakeServer` in default `.ok` mode. It never exercises `.commitThenTimeout`, so the reported scenario has no coverage and the test passes despite the bug.
- The test can also be flaky. The `Task` started by `submit` may run first, so the explicit `flush()` hits the `flushing` guard and returns before the post completes, and the assertion could see 0 orders. I did not run it, so this is a reasoning-only concern.
- `FakeServer` has no deduplication, so even with a client fix it could not show the fix working.

## What I could not verify
- **Server behaviour.** `CONTEXT.md` says the API reference documents only a JSON body and that nothing in the repo describes duplicate handling. I do not know whether the backend supports an `Idempotency-Key` header, a client-supplied order ID or dedup, or whether it would ignore a new field.
- **Where the timeout comes from.** I cannot tell whether the lost-response timeout comes from the transport or a proxy. There is also no real `OrdersAPI` implementation here, so I could not see what the app treats as retryable.
- **Real-world evidence.** Whether the support reports match this scenario is unconfirmed. Logs or server timestamps showing duplicates a few seconds apart with identical payloads would confirm it.
- **Other code.** Other callers of `OrderOutbox`, app lifecycle behaviour, and other flows that could create duplicates, such as a user double-tapping submit, are outside this directory.

## What I would change, in order
1. **Ask the backend team** whether `POST /orders` supports an idempotency key or client-generated order ID, and what dedup window and response semantics it has (same key replied with the original 200/201, or a 409). Without this, no client change can fully guarantee exactly-once.
2. **Add a stable ID to `Pending`.** Use `let id: UUID`, generated once in `submit`. Make decoding backward-compatible for queues already on disk, for example by assigning an ID to old entries on load.
3. **Send the ID with every attempt.** Extend `OrdersAPI.post` with an idempotency key parameter, sent as a header or body field as the backend agrees. Reuse the same key on all retries, including after relaunch.
4. **Classify errors.** Retry only transient failures (timeouts, connection loss, 5xx), with backoff and a cap. Treat a permanent 4xx as a failure to surface or park, so it does not block the queue.
5. **Harden persistence.** Use atomic writes and handle encode and write errors. Do not silently discard a file that fails to decode.
6. **Make flush deterministic.** Let callers await a real drain, or use a single long-lived drain task instead of the guard-and-return pattern.
7. **Tests.**
   - Add a test using `commitThenTimeout` that asserts exactly one order after retry.
   - Make `FakeServer` dedupe by key, to match the agreed backend contract.
   - Add a test that persists, "crashes" and relaunches mid-flight, and a test that a permanent 4xx does not block the queue.
