# Lumen Notes Pro: StoreKit entitlement review (source only, nothing built or run)

Files: CONTEXT.md, LumenApp.swift, EntitlementManager.swift, PaywallView.swift, Products.storekit.json.

## Summary
The reported symptoms are (a) refunded users keep Pro until relaunch, and (b) an Ask-to-Buy / family-sharing approval does not unlock Pro until relaunch. The source does NOT show a defect that explains them. The listener design is sound as written, and the refund path is correct on paper. I could not find an observed transition failure. I found source-supported risks that could plausibly contribute, and a list of things that need runtime evidence. I recommend only small hardening changes, not a rewrite, and I would not claim a root cause.

## Ownership map
- Product type: one auto-renewing subscription group "pro", monthly and yearly, both familyShareable (Products.storekit.json:6-10). IDs match EntitlementManager.swift:11-13.
- Authority: device only, StoreKit 2, no server (CONTEXT.md:1). `isPro` is the sole gate (EntitlementManager.swift:7).
- Persistence: none. `isPro` is recomputed from `Transaction.currentEntitlements` at launch and on each event.
- No app-account concept, so account switching and cache-leak concerns do not apply.
- Not a consumable or non-renewing app, so ledger and idempotency concerns do not apply.

## State table (as implemented)
| State | Represented? | Evidence |
|---|---|---|
| unknown/loading | No. `isPro` defaults to false (EntitlementManager.swift:7) until the first refresh completes | A paying user is treated as not entitled during launch |
| entitled | `isPro == true` | :61-65 |
| not entitled | `isPro == false` | :58, :65 |
| pending | Not represented; `.pending` is a no-op (:44-45) | Correct for granting, but no UI feedback |
| recoverable failure | Not represented | Product load failure is swallowed (:21); `AppStore.sync` failure is swallowed (:52) |

## Findings

### 1. Listener lifecycle matches the design note (no defect found)
- `EntitlementManager.init()` calls `startListening()` (:15-17). The manager is created once in `LumenApp` as `@State` (LumenApp.swift:5). The loop `for await result in Transaction.updates` (:29) runs for the object's lifetime, independent of the visible screen. The documented design in CONTEXT.md:9 is accurate for the code shown.
- The loop is guarded against a double start (:27), holds `self` weakly, and calls `refresh()` after each verified update (:30-32).
- So "the paywall isn't on screen, therefore the update is missed" is not supported by the source. Do not "fix" this by moving the listener.

### 2. Refund path is correct in the code (source-supported, not an observed failure)
- A refund arrives as a verified update with `revocationDate` set. The loop finishes it and calls `refresh()`. `refresh()` recomputes `active` from scratch (:58-65), so access CAN be removed: it is not an insert-only reducer. `revocationDate == nil` (:61) is also checked, and is redundant with currentEntitlements semantics but harmless.
- So the "stays Pro until relaunch" symptom is not explained by reducer logic. Candidates that the source cannot confirm or exclude:
  - (a) Timing: Apple may deliver the revocation to `Transaction.updates` late, or only on next launch, so the live listener never fires. The relaunch fixing it matches the launch `refresh()` at LumenApp.swift:13 seeing the revoked state. This is an App Store delivery behavior that I cannot verify from files.
  - (b) `currentEntitlements` could still return the transaction right after the update event. If so, the immediate `refresh()` at :32 reads stale data and nothing triggers another read. No code retries or refreshes later.
  - (c) The update arrives while the app is suspended or in the background, and nothing re-reconciles on foreground (see finding 3).
- I cannot distinguish these without logs or a sandbox refund test. CONTEXT.md:7 confirms none exist.

### 3. No foreground or periodic reconciliation (source-supported risk, probably the most useful change)
- The only `refresh()` calls are: launch (LumenApp.swift:13), after an update (:32), after purchase (:43), and in restore (:53). There is no `scenePhase == .active` refresh, so a long-lived process that missed or got a stale event stays wrong until relaunch. That is exactly the shape of both complaints.
- Subscription expiry has the same gap: `isPro` stays true after `expirationDate` passes until some other event triggers `refresh()`. `refresh()` also never looks at `expirationDate`; it relies fully on `currentEntitlements`.
- Suggested fix: refresh on `scenePhase` becoming `.active` (cheap, no auth prompt), and optionally schedule one refresh at the earliest known expiration.

### 4. Ask to Buy / family sharing (not confirmed; mostly a delivery question)
- The purchase code is right for the child case: `.pending` grants nothing and does not finish (:44-45). Approval is expected to arrive via `Transaction.updates`, which the listener handles (:29-32). Family-shared entitlements are `familyShareable: true` in config and appear in `currentEntitlements`.
- "Unlocks after relaunch" again points either to late or non-delivery of the update to a running process, or to stale reads (finding 2b). Source cannot settle it. The same foreground refresh (finding 3) is the practical mitigation. The Restore button (PaywallView.swift:18-20) works as a manual workaround.
- The paywall gives the child no "waiting for approval" state, so users may think the purchase failed (:44-45 silently breaks).

### 5. Concurrent refreshes can commit out of order (source-supported risk)
- `refresh()` is `@MainActor` but suspends in `for await` (:59). The launch refresh (LumenApp.swift:13), listener refreshes, purchase refresh and restore refresh can interleave. Each writes `isPro = active` at the end (:65) with no generation token, so an older enumeration that finishes last can overwrite a newer one. Plausible with a revocation arriving at launch right as the launch refresh is in flight. Low-to-medium likelihood; not provable from source.
- Fix: a monotonically increasing generation (or a single serialized reconcile task) and discard results from stale generations.

### 6. Unverified transactions are silently turned into "not entitled" (source-supported risk)
- `guard case .verified ... else { continue }` (:60) drops unverified entries. If every entitling transaction is unverified, or enumeration finishes partway, `isPro` becomes false as though the user had no purchases (:65). This conflates verification failure with a completed empty snapshot, and can revoke legitimate access (e.g. transient verification failure). Likewise the listener (:30) and purchase (:41) drop unverified results with no signal; in `purchase` the user sees nothing happen.
- Recommend tracking verification failure separately and keeping prior state (or showing a recoverable-failure state) rather than committing an empty result. Direction of failure here is lost access, not unauthorized access.

### 7. Smaller points
- Launch state: `isPro = false` until the first refresh finishes (EntitlementManager.swift:7), so entitled users briefly see locked content. A tri-state (unknown/entitled/not) would avoid this.
- `loadProducts()` swallows errors and yields an empty paywall (:21). No retry or message.
- `restore()` calls `AppStore.sync()` (:52) only from the explicit button (PaywallView.swift:19), which is the right place; the `try?` hides auth cancellation or failure from the user.
- Finishing before refresh (:31, :42) is fine for subscriptions; no delivery step could fail between them.
- `@State private var entitlements = EntitlementManager()` (LumenApp.swift:5): if the App struct were ever re-initialized, a discarded instance would still have started a `Transaction.updates` task (init side effect, weak self). I consider this unlikely to matter on the described OS versions and cannot verify it from files. Moving the manager to a shared singleton would remove the question.
- Unverifiable: grace period and billing-retry policy. The code has no explicit business rule; the config JSON defines none. Decide intentionally whether those users stay Pro.

## What I could not verify from the files
- Whether Apple actually delivers refund revocations or Ask-to-Buy approvals to a running iOS 17/18 process via `Transaction.updates`, and with what delay.
- Whether `currentEntitlements` reflects the change at the moment the update event fires (finding 2b).
- Any real behavior: no build, no StoreKit test run, no logs. The local `.storekit` config says nothing about production delivery, and local simulation can't prove it either.
- Whether the shipped build matches this source, or whether other code (RootView, other call sites) mutates entitlement state. RootView isn't in the review set.

## Recommended changes (small, in priority order)
1. Add a foreground/`scenePhase == .active` reconciliation call to `refresh()`.
2. Serialize or generation-guard `refresh()` so stale snapshots cannot overwrite newer ones.
3. Track verification failure and enumeration failure separately; do not commit `isPro = false` from them.
4. Introduce an unknown/loading entitlement state and a pending (awaiting approval) state in the paywall.
5. Surface product-load and restore errors.

## Verification plan (needs a runtime)
- StoreKitTest with a local config: observe verified access, then a simulated refund, and wait with a bounded deadline for an identifiable `Transaction.updates` revocation event and for `isPro == false`. Also separately test a launch-time snapshot after refund. Assert the pre-refund state (empty to empty proves nothing).
- Ask to Buy: simulate pending, then approval; confirm the update arrives in a live session.
- These local results cannot prove production delivery timing. Use sandbox/TestFlight with logging of update events and `currentEntitlements` contents (without logging receipts or personal data) to confirm findings 2 and 4.
