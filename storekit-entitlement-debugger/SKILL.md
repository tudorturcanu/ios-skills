---
name: storekit-entitlement-debugger
description: "Diagnose and fix StoreKit purchase and entitlement inconsistencies, including restoration, pending purchases, renewal, refund, revocation, and account changes. Use for entitlement lifecycle bugs, not paywall visual design or pricing advice."
---

# StoreKit Entitlement Debugger

Trace transactions into access decisions; a purchase button returning success is not the entire entitlement lifecycle.

## Map ownership

Identify product types, product IDs, subscription groups, purchase entrypoints, transaction listeners, persistence, and any backend entitlement service. Record which layer is authoritative and how app accounts relate to App Store purchases. Inspect verification results, transaction identifiers, and account association without logging receipts, tokens, or personal data unnecessarily.

Construct a state table for unknown/loading, entitled, not entitled, pending, and recoverable failure. Do not collapse an unavailable network response into a proven loss of access. Identify business rules for grace periods and non-renewing subscriptions explicitly.

## Trace updates

Review initial entitlement reconciliation, long-lived transaction updates, purchase results, foreground refresh, and user-initiated restore. Handle verified and unverified results explicitly; never grant trusted access merely because a transaction object exists. Pending and user-cancelled purchases must not grant a new entitlement. Finish transactions after the appropriate delivery/persistence succeeds, with idempotency for duplicate delivery.

For fulfillment bugs, simulate one verified transaction arriving through both the purchase result and the updates listener while the first delivery is still in flight. Verify that the same transaction produces one durable delivery and that a restart or failed delivery can recover. For a consumable, assert the resulting balance as well as the fulfillment record.

Check that recomputation can remove obsolete access as well as add it. Current entitlements do not provide a consumable balance: inspect a durable, idempotent fulfillment ledger for consumables. For non-renewing subscriptions, evaluate the app's validity rules rather than assuming presence means unexpired access. Avoid routine automatic AppStore.sync calls that may prompt for authentication; reserve explicit restore synchronization for the intended user flow.

Do not turn a sequence containing unverified transactions into a healthy empty snapshot by silently filtering them out. Track verification failure and interrupted enumeration separately from completed reconciliation, and reject obsolete account/generation results before committing access changes.

Inspect expiration, revocation, upgrade, grace-period and billing-retry handling against the actual product/status semantics. For a product-specific query, check deployment availability and prefer the current entitlement sequence when supported. Advanced Commerce generic product IDs can yield multiple entitling transactions. For apps with volume purchases, include assigned ownership and assignment revocation on supporting OS versions. [Product entitlement API](https://developer.apple.com/documentation/storekit/transaction/currententitlements%28for%3A%29) · [iOS and iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes) App-account logout and switching must not leak the previous account's cached access. Do not equate app-account identity with the device's store account.

For a multiseat subscription, check its purchase options in App Store Connect and verify the entitlement for the purchaser or seat recipient in the actual account. One product ID can sell both individual and group access. Exercise assignment or invitation acceptance and later access loss. Compare group purchases with managed volume assignments only where the app supports both. Check individual API availability before changing behavior on older runtimes. [Apple’s multiseat guide](https://developer.apple.com/documentation/storekit/supporting-multiseat-purchases-in-your-app)

## Verify

Build a StoreKit test matrix covering success, cancellation, pending approval, duplicate updates, restore after reinstall, expiration, refund/revocation, and account changes relevant to this product. Test offline launch and interrupted fulfillment. Separate local StoreKit configuration results from sandbox/server notification evidence. Never claim a backend flow is tested using only local purchase simulation.

For snapshot regressions or StoreKitTest automation, read [reconciliation and local tests](references/reconciliation-tests.md). StoreKit test sessions share environment settings; serialize tests that mutate them rather than assuming a new session isolates each test.

Return the entitlement state diagram/table, identified transition failure, scoped fix, and results with test environment and limitations.

## Diagnostic cases

Read [diagnostic cases](references/diagnostic-cases.md) when choosing the next experiment or building a regression test. Use the cases that match the observed failure.

## Reference

Check [currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements) and its linked transaction APIs before changing product-specific eligibility rules.
