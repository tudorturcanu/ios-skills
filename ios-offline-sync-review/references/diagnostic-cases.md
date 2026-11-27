# Distinguish ambiguous delivery from a failed operation

An order request times out after the server commits. The client knows the reply was lost, not whether the order exists. Retrying a non-idempotent POST can create another order; marking it failed and dropping it can lose the user's intent.

Investigate the server's operation identifier/deduplication contract or a supported reconciliation query. A client-generated ID helps only if the server honors it. Test retries with the same ID across process restart and verify one server effect plus a durable local acknowledgment.

| Fault injection | Invariant to observe |
| --- | --- |
| Terminate after local edit before enqueue | Either both edit and intent persist, or the UI clearly reports the unsaved operation |
| Timeout after server commit | Recovery resolves ambiguity without duplicate effects |
| Account switch during response | Old response cannot mutate the new account's state |
| Crash after page apply before cursor persist | Replay is idempotent; no permanent data skip |
| Permanent validation error | User retains actionable failure information; retries do not loop forever |
| Later batch item fails after earlier acknowledgments | Recovery retains the unresolved suffix and its dependencies without treating the successful prefix as unsent |
| Retry occurs after server deduplication expires | The client reconciles or exposes uncertainty instead of assuming the key prevents another effect |

Evaluate the actual product contract. A sync policy that deliberately allows conflicts is not a defect merely because another policy is possible.
