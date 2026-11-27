# Review: Lumen Notes Pro refund / Ask-to-Buy not applied until relaunch

Scope: source only (CONTEXT.md, EntitlementManager.swift, PaywallView.swift, LumenApp.swift, Products.storekit.json). Nothing was built or run.

## Bottom line
I did not find a source defect that explains the complaint. The "Transaction.updates listener is alive for the whole app lifetime" design note is accurate in the code, and the listener handles refunds and Ask-to-Buy approvals the way Apple documents. The code has real robustness gaps, and the symptoms are consistent with delayed or missed delivery on the StoreKit/OS side, which these files cannot show. I do not recommend a root-cause "fix" claim; I recommend the defensive changes below, and device-side evidence to confirm.

## What the code does (evidence)
- Listener lifetime: `LumenApp.swift:5` creates `EntitlementManager` in `@State`. `EntitlementManager.swift:15-17` (`init`) calls `startListening()`. `:26-35` starts one `Task` iterating `Transaction.updates`, guarded against duplicates by `updatesTask == nil` (`:27`). It is not tied to PaywallView, so the premise holds: updates are observed regardless of screen. `PaywallView.swift` only calls `loadProducts()` and `purchase/restore`.
- Update handling (`:29-33`): verified transaction, then `finish()`, then `refresh()`.
- Refresh (`:57-66`): iterates `Transaction.currentEntitlements`, sets `isPro` true if a verified transaction has an id in `productIDs` and `revocationDate == nil`. A refunded/revoked transaction is not returned by currentEntitlements anyway, and the revocationDate check is a harmless extra.
- Launch: `LumenApp.swift:11-14` calls `refresh()` once in `.task`.
- Purchase (`:37-49`): `.success` verified -> finish -> refresh (why paywall purchases unlock instantly); `.pending` does nothing, so Ask-to-Buy relies entirely on the updates listener later.
- Logic for refund -> updates -> refresh -> isPro=false and Ask-to-Buy approval -> updates -> refresh -> isPro=true is correct on paper. Both complaints say the effect appears only after relaunch (where `LumenApp.swift:13` refresh runs), which implies the live path either did not fire or fired and saw stale data.

## Findings (ordered by how plausibly they relate to the report)

1. No refresh trigger other than the updates stream and launch (medium relevance, `LumenApp.swift:11-14`, `EntitlementManager.swift`). If the refund/approval event is delivered late, coalesced, or not delivered while the app is suspended (iOS may not wake or replay until the process restarts), nothing re-checks when the app returns to the foreground. A backgrounded-not-killed app can stay Pro for days, matching "until force-quit and relaunch". Fix: refresh on `scenePhase == .active` (or `.task(id: scenePhase)`), and optionally on a timer at the subscription expiry.

2. Unverified updates are dropped without a refresh (`:30` `else { continue }`). A refund/revocation arriving as `.unverified` (for example on a device where verification fails) is ignored and not finished, so isPro never changes. Safer: on any update, still call `refresh()`; treat unverified results as not entitling (refresh already ignores them at `:60`).

3. Concurrent `refresh()` calls can interleave (`:57-66`). The class is `@MainActor`, but `for await` suspends, so launch refresh, update-triggered refresh and purchase refresh can overlap and a slower, older snapshot can write `isPro` last. Narrow, but it could re-enable Pro after a revocation. Fix: serialize (cancel the previous refresh task or use a generation counter) or compute on the update's own transaction.

4. Update path trusts a single `currentEntitlements` read right after the event (`:32`). If StoreKit's local entitlement cache has not yet absorbed the revocation when the update fires, `refresh()` can still see it as active, and nothing retries. I cannot verify cache timing from source; it ties back to finding 1 (a later refresh would repair it). A direct hint is available: when the update itself has `tx.revocationDate != nil` (or its expiry is past), you could set the state from the transaction rather than only from the re-read.

5. Possible duplicate listeners (low, unverified). `@State private var entitlements = EntitlementManager()` (`LumenApp.swift:5`) evaluates the initializer expression whenever the `App` struct is re-initialised; SwiftUI keeps only the first instance, but the discarded instances' `init` have already started listener Tasks (they hold `self` weakly, but the Task and `for await` stay alive). Orphan listeners could consume and `finish()` an update with `self == nil`, so the live instance never sees `refresh()` (`:32` `await self?.refresh()`). I cannot confirm from files whether App is re-initialised in production, or whether multiple Transaction.updates iterators each receive every element (Apple docs say a single listener should be used). Hardening: create the manager once (e.g. lazy start in `.task`, or a shared singleton), and add `deinit`/cancellation.

6. Errors swallowed: `restore()` ignores `AppStore.sync()` failure (`:52`); `loadProducts` returns `[]` on error (`:21`); in `purchase`, an `.unverified` success returns silently with no error and no finish (`:41`). Not related to the complaint, but hides diagnosable failures. Also isPro starts `false` (`:7`) until the first refresh, so paid users may see a locked state briefly at launch.

7. Subscription expiry has no event. If isPro depends only on updates, lapsed subscriptions (not refunds) stay Pro until a refresh. Same remedy as finding 1.

8. Family Sharing / Ask to Buy. `Products.storekit.json:9-10` has `familyShareable: true`, so family members' entitlements can appear in `currentEntitlements` with `ownershipType == .familyShared`; the code treats them equally (reasonable). The code does not check `ownershipType` or handle sharing being removed other than via revocation. Ask to Buy approval on the parent's phone reaches the child device through Transaction.updates only when the OS delivers it; no code path polls for it.

## What I could not verify from the files
- Whether StoreKit actually delivered the refund/approval to the running process, and when (no device logs; iOS 17 vs 18 timing differences).
- Whether `Transaction.currentEntitlements` is already updated when the update is delivered.
- Whether `LumenApp` is re-initialised (finding 5) and how multiple iterators behave.
- `RootView` is not provided; I cannot see how `isPro` is consumed, whether anything caches it (e.g. UserDefaults), or whether Pro features read a stale copy.
- Whether the config file reflects the production App Store Connect setup: `Products.storekit.json` has no localizations or offers and is only a local testing config. Its `_failTransactionsEnabled` is false. It cannot reproduce refund delivery delays.
- Whether affected users are on the shipped build containing this code, and whether the refunds were processed for these exact product ids.

## Recommended changes (defensive, not a proven root-cause fix)
1. Add a foreground refresh: `.onChange(of: scenePhase) { if $1 == .active { Task { await entitlements.refresh() } } }` (or `.task(id:)`).
2. In the listener, call `refresh()` for every update, including unverified ones; keep `finish()` only for verified.
3. Serialize `refresh()` so only the newest result is applied.
4. Ensure the manager (and its listener) is created exactly once; cancel the task in cleanup.
5. Surface errors from `restore()`, `loadProducts()` and unverified purchases.
6. To confirm the diagnosis, add logging (transaction id, revocationDate, event source, isPro before/after) and collect it from affected users; reproduce with Xcode Transaction Manager refund / Ask-to-Buy approval while the app is foregrounded, backgrounded and killed.

Confidence: high that the listener wiring matches the documented design note and handles refund/approval events when delivered; low-to-medium that any listed gap is the actual cause.
