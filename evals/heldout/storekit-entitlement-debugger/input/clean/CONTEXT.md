# Context: Lumen Notes Pro (iOS 17+, StoreKit 2, no server)

One auto-renewing subscription group "pro" with products `com.lumen.pro.monthly` and `com.lumen.pro.yearly` (see Products.storekit.json). Pro features are gated by `EntitlementManager.isPro`.

Support complaint: "Several users who were refunded through Apple still have Pro features days later, until they force-quit and relaunch the app. Also a family-sharing/Ask-to-Buy child says approval happened on the parent's phone but Pro did not unlock until relaunch." Normal purchases from the paywall unlock immediately. Reports come from production users on iOS 17 and 18.

No device logs are available. Review the source only.

Documented design note: `EntitlementManager` is created once at app launch (`@State` in `LumenApp`) and its initializer starts the single `Transaction.updates` listener, so updates are observed for the app's whole lifetime regardless of which screen is showing.
