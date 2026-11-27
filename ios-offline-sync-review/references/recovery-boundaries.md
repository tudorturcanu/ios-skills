# Partial completion and retry identity

## Preserve each operation's outcome

A thread, upload-and-publish flow, or batch can complete only a prefix of its work. A single optional result or failure flag may discard the server IDs already acknowledged. Record each completed step, the failing or ambiguous step, and the untouched suffix. Preserve dependencies such as the server ID to which a remaining reply must attach.

On recovery, resume unresolved work according to the server contract. Do not blindly resubmit the original batch, and do not try to undo acknowledged work unless the product actually supports and requests that behavior. After an ambiguous response, distinguish “not known to have succeeded” from “known not to have succeeded.” An ordinary list search is not necessarily authoritative reconciliation: visibility, pagination, and delayed indexing can hide an existing effect.

Probe at least these boundaries when applicable:

| Boundary | Observable assertion |
| --- | --- |
| First step fails before acknowledgment | Every unresolved item remains recoverable |
| A later step fails after a successful prefix | Known server IDs survive; recovery neither drops the suffix nor republishes the prefix |
| Commit succeeds but response is lost | Reconciliation or documented deduplication resolves uncertainty |
| Acknowledgment arrives, then ancillary work fails | Presentation delays, haptics, or follow-up bookkeeping do not relabel the acknowledged server effect as unsent |
| Process restarts during recovery | Operation identity, payload, dependencies, and ownership are restored together |

## Check the recovery artifact, not its label

Follow the error handler to the actual write and reopen path. A text-only draft cannot necessarily restore attachments, poll choices, visibility, reply targets, account identity, or several pending items. A blank text guard may also omit a valid media-only operation. Evaluate which fields matter to this product rather than requiring every possible field.

Verify durability before claiming the content was saved. An insertion into an in-memory context is not a demonstrated disk commit. If the feature is only a convenience draft, preserve that scope and state its limitations; do not prescribe a full outbox without a product requirement. Avoid storing credentials in operation payloads when a stable account reference suffices.

## Bind retry identity to one logical mutation

Inspect the endpoint's actual contract: supported method, key scope, payload mismatch behavior, concurrent requests, response reuse, and retention window. A header accepted by one endpoint or server version is not a universal guarantee. Do not apply a status-publication contract to media uploads without evidence.

Generate an operation identity once and persist it with the account, endpoint, immutable request payload, and recovery state when restart recovery is required. Reuse it for retries of that same mutation. A fresh key per attempt defeats deduplication; a content hash alone can also merge two intentionally identical user actions. Editing an unresolved operation requires an explicit policy for reconciling the old effect before treating the edit as a new mutation.

After server deduplication expires, the same key may create a second effect. Use supported authoritative reconciliation, a longer-lived server operation record, or an explicit unresolved state with user recovery. Do not silently rotate keys and call the result safe. As a concrete bounded contract, Mastodon's [status creation endpoint](https://docs.joinmastodon.org/methods/statuses/#create) documents idempotency-key retention of up to one hour; verify the actual server and current API when reviewing an app.
