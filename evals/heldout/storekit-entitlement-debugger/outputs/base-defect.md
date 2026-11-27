# Review: Lumen Notes Pro entitlement behavior (source-only)

## Verdict
Root cause: the `Transaction.updates` listener is started only from `PaywallView`'s `.task` (PaywallView.swift:23-26 -> `startListening()`), not at app launch. `LumenApp` (LumenApp.swift:11-14) only calls `refresh()` once at launch. Any user who never opens the paywall in a given process has no listener, so refunds, revocations and Ask-to-Buy approvals that arrive outside an in-app purchase are not seen until the next launch re-runs `refresh()`.

## Evidence
- LumenApp.swift:11-14: launch does a single `await entitlements.refresh()`. There is no `startListening()` call, and no foreground or scenePhase refresh.
- PaywallView.swift:23-26: `loadProducts()` then `startListening()`, inside the paywall view's `.task`. This is the only call site of `startListening()` in the project.
- EntitlementManager.swift:21-30: `startListening` is correct in itself (verified-only, `finish()`, then `refresh()`), but it is guarded by `updatesTask == nil` and nothing else starts it.
- EntitlementManager.swift:52-61: `refresh()` is correct. `currentEntitlements` already omits revoked and expired transactions, and the `revocationDate == nil` check is redundant but harmless.

## Why it matches the complaint
1. Refunded users keep Pro until relaunch. Paying Pro users have no reason to open the paywall, so the listener never starts for them. Apple's revocation arrives via `Transaction.updates`, nobody is listening, and `isPro` stays true until the next launch runs `refresh()`. This also explains "normal purchases unlock immediately": `purchase()` calls `refresh()` itself (lines 32-38) and does not depend on the listener.
2. Ask to Buy and Family Sharing child. `purchase()` returns `.pending` and does nothing more (line 39). The approval later arrives only through `Transaction.updates`. If the child left the paywall (the listener is an unstructured Task and survives navigation) it would still work, but it was never started if the paywall was not shown in this process. The process may also have been killed and relaunched, in which case the listener is not running until the paywall is opened again. That matches "unlocks on relaunch". Family-shared entitlements for a family member who never purchased also arrive only through `Transaction.updates` and `currentEntitlements`.
3. iOS 17 and 18 both behave this way. This is app logic rather than an OS version difference.

## Recommended change
- Start the listener at app launch, before the first `refresh()`, so no update is missed. For example, in `LumenApp` `.task`: `entitlements.startListening(); await entitlements.refresh()`. Alternatively start it in `EntitlementManager.init()`, since the Task already uses `[weak self]` and the class is `@MainActor`. Remove `startListening()` from `PaywallView`.
- Optional hardening:
  - Refresh on `scenePhase == .active`.
  - Cancel `updatesTask` in `deinit`.
  - Surface `.pending` ("waiting for approval") and unverified results to the user. Today an unverified purchase silently returns (line 36) and `.pending` shows nothing.
  - Handle the `AppStore.sync()` error (line 47, `try?` swallows it) and the `Product.products` failure (line 16, silently returns an empty list).
  - Process `Transaction.updates` verified and unverified results explicitly. Unverified ones are currently dropped without being finished.

## Could not verify from files alone
- Not run or built; no device logs. I could not confirm timing, or that these specific users never opened the paywall.
- Whether other call sites exist beyond these 5 files (only these were provided; `RootView` is not included, so a hidden `startListening()` call there cannot be ruled out).
- Actual delivery latency of Apple refund and Ask-to-Buy notifications to the app. StoreKit may also deliver them when the app is foregrounded, so symptom timing ("days later") depends on the user's launch habits.
- Whether `Products.storekit.json` matches App Store Connect configuration (family sharing is enabled in the local config only). Note this file has no refund or Ask-to-Buy test setup information.
