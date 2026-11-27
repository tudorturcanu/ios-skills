# Lumen Notes Pro: refund and Ask-to-Buy entitlement review (source-only)

Files reviewed: CONTEXT.md, EntitlementManager.swift, PaywallView.swift, LumenApp.swift, Products.storekit.json. Nothing was built, run or modified.

## Ownership map
- Products: auto-renewing subscriptions `com.lumen.pro.monthly` and `com.lumen.pro.yearly`, group "pro", both familyShareable (Products.storekit.json:9-10).
- Authority: on-device only. There is no server, and `EntitlementManager.isPro` (EntitlementManager.swift:7) is recomputed from `Transaction.currentEntitlements`. Nothing is persisted. There is no app-account concept.
- Purchase entry: `purchase(_:)` (EntitlementManager.swift:32), called from PaywallView.swift:13. Restore: `restore()` (EntitlementManager.swift:46).
- Reconciliation: `refresh()` (EntitlementManager.swift:52). It is called once at launch (LumenApp.swift:13), after a purchase, after an update, and after restore.
- Updates listener: `startListening()` (EntitlementManager.swift:21).

## State table (as implemented)
| State | Represented? |
|---|---|
| unknown/loading | No. `isPro` starts `false` (line 7), so unknown looks like not entitled until the first `refresh()` finishes. |
| entitled | `isPro == true` |
| not entitled | `isPro == false` |
| pending | Not tracked. It is a `break` (line 39-40), which is correct for not granting access, but nothing records it. |
| recoverable failure | Not represented. Verification failures are dropped silently. |

## Primary finding (observed transition failure, source-supported): the updates listener only starts when the paywall appears
`startListening()` is called in exactly one place: the `.task` of `PaywallView` (PaywallView.swift:23-26). `LumenApp.swift:11-14` only calls `refresh()` once at launch and never starts the listener. `startListening` is not called anywhere else in the provided files.

Consequences:
- A subscriber who is already Pro normally never opens the paywall in a session. No `Transaction.updates` consumer exists for that session, so a refund or revocation is never delivered. `isPro` stays `true` until the next launch, when `LumenApp`'s `.task` runs `refresh()`. That matches "refunded users keep Pro until force-quit and relaunch".
- Ask to Buy: the child's `purchase()` returned `.pending` (line 39). The parent's approval later arrives only through `Transaction.updates`. If the paywall has been dismissed or was never re-shown in this process, nobody is iterating it, so nothing happens until relaunch. The relaunch `refresh()` then picks it up. That matches the second complaint. The same applies to a family-shared entitlement that arrives from another device.
- Normal purchases work because `purchase()` calls `refresh()` directly (line 38). That is why the "purchases unlock immediately" part of the report is consistent with this cause.
- The listener is also started after `await entitlements.loadProducts()` (PaywallView.swift:24-25). If product loading is slow, listening is delayed further.

Fix (scoped):
- Start the listener once at app launch, before or alongside the initial `refresh()`. For example, call `entitlements.startListening()` in `LumenApp`'s `.task` or in the manager's init, and remove it from `PaywallView`.
- Keep the existing `guard updatesTask == nil`, so repeated calls are harmless.
- Also call `refresh()` on `scenePhase == .active`, as a safety net for missed events.

## Secondary findings
1. **Verification failures are silently turned into "no access"** (EntitlementManager.swift:55, `continue`). If a verified subscription is followed or preceded by an unverified element, or if verification fails transiently, `active` stays `false` and `isPro = false` (line 60) is committed as a completed, healthy empty reconciliation. This can remove legitimate access. It is the opposite risk to the reported bug. The code should track verification failures separately and decide on a policy, for example keeping the prior state. Risk, not observed.
2. **No cancellation or staleness handling in `refresh()`.** `isPro = active` (line 60) is committed unconditionally. Concurrent calls from the listener, purchase, restore and launch can interleave, and a slower older snapshot can overwrite a newer one. This is source-supported risk, not shown to cause the complaint. A generation counter or serialization would fix it.
3. **Unverified listener results are dropped without any record** (line 25), and `purchase()` returns silently for an unverified result (line 36). The user sees no error and no state change. Nothing is granted, which is safe, but it is invisible and the transaction is never finished.
4. **`tx.finish()` is called before `refresh()`** (lines 26, 37). For a subscription, with no server and no durable delivery step, that is acceptable. If a backend or ledger is added later, finish only after delivery succeeds. Duplicate delivery is harmless today because `refresh()` is idempotent.
5. **`tx.revocationDate == nil` (line 56) is redundant but harmless.** `currentEntitlements` already excludes refunded and revoked transactions. The explicit check is fine. It does not cause the bug, and it does not itself prove that refunds are handled. The real removal path is the recomputation in `refresh()`, which does correctly allow `isPro` to go from true to false. The listener is what is missing.
6. **Grace period and billing retry are not evaluated explicitly.** The code relies on `currentEntitlements` semantics. If the business wants grace or retry users to keep access, that needs `Product.SubscriptionInfo.Status` and is not covered here. The business rule is not stated in CONTEXT.md.
7. **`restore()` swallows errors** (line 47, `try?`). A failed or cancelled `AppStore.sync()` still proceeds to `refresh()` and gives the user no feedback. Calling it only from the explicit Restore button is appropriate.
8. **`loadProducts()` failure is silent** (line 16). It yields an empty list and an empty paywall with no error.
9. **Cached `isPro` while unknown.** Launch shows non-Pro until the first `refresh()` completes, and there is no offline distinction. The code does not collapse a network error into loss of access, because `currentEntitlements` is local. A failure mode of the enumeration itself is not observable here.
10. **Family sharing detail:** `tx.ownershipType` is not examined. For family-shared access, the revocation path is also only delivered through `Transaction.updates`, so the primary finding applies equally to a parent leaving the family or ending sharing.

## What could not be verified from the files
- No logs, so the actual cause in production is inferred from the source. It fits both complaints well but is not confirmed at runtime.
- `RootView` and any other code are not provided. If something else calls `startListening()` (for example `RootView`), the primary finding would not hold. Only the files listed above were searched.
- Whether Apple's refund notification reaches a running app promptly depends on the OS and network. A relaunch always resolves it through `refresh()`, as reported.
- iOS 17 vs 18 behavioral differences, the Ask-to-Buy approval flow end to end, and sandbox or production behavior cannot be checked without running. No StoreKit test results exist, and local StoreKit configuration testing would not prove production delivery of refund events.

## What should change (ranked)
1. Start `Transaction.updates` observation at app launch, not from the paywall. This fixes both complaints.
2. Refresh on foreground.
3. Serialize or generation-guard `refresh()`, and track verification failures separately rather than treating them as empty.
4. Add an unknown/loading state for `isPro`.
5. Regression tests: verified Pro followed by a refund must drop `isPro` without relaunch, with the listener running while the paywall has never been shown. Ask-to-Buy pending followed by approval must unlock without relaunch. Test with `SKTestSession` (local only), and serialize the tests.
