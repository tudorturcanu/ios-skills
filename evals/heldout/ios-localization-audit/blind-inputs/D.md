# Localization review: Kiosk (en, de, ru)

Scope: `Localizable.xcstrings`, `CartView.swift`, `OrderSummary.swift`, `CONTEXT.md`. Source review only. I ran the guidance's two read-only helper scripts (stdout only, nothing written); no build, simulator, or edits.

## Findings

### 1. Russian cart header is missing the `few` and `many` plural categories (confirmed defect, explains the ticket)
`Localizable.xcstrings` lines 43-60 (`cart.items.count`, `ru`) define only `one` ("%lld товар") and `other` ("%lld товаров"). Russian CLDR needs `one`, `few`, `many`, `other`, as CONTEXT.md states. Missing categories fall back to `other`, so:
- 2, 3, 4, 22, 23, 24 (`few`) render "товаров"; correct is "товара". This is the ungrammatical wording in the ticket.
- 5-20, 25-30 (`many`) render "товаров", which is correct by accident.
- 1, 21, 31 (`one`) render "товар", which is correct.
- Fractions and other `other` cases such as 1.5 would need "товара"; the app passes an integer count, so this is theoretical.

The ticket example "5 items" should read correctly under the current data. Either the reporter's example is imprecise or something else is wrong (see finding 3). I cannot tell which from the source.

Both entries are marked `"state": "translated"`, so Xcode shows no warning, and the inventory script reported zero findings. The script does not check plural categories (its own limitations say so). A clean script run is not evidence that this is fine.

Fix: add `few` ("%lld товара") and `many` ("%lld товаров") to the `ru` plural variation and keep `one` and `other`. Because `other` is the fallback for non-integers, "%lld товара" is the grammatically right value for it as well. Do not guess this as final: a Russian reviewer should sign off on the wording. Do not mark the new entries reviewed merely to satisfy a completeness count.

### 2. English and German plurals are fine
- `en`, lines 8-23: `one`/`other` is correct.
- `de`, lines 26-41: `one` and `other` are both "%lld Artikel". That is valid because "Artikel" is invariant, and `one`/`other` is the right category set. Having both entries identical is redundant, not wrong.
- The `%lld` placeholder is consistent across all three languages and matches an `Int` argument (`items.count`).

### 3. Catalog keys likely do not match what the call sites look up (needs a build to verify)
SwiftUI builds the lookup key from the literal including interpolation placeholders:
- `CartView.swift:10` `Text("cart.items.count \(items.count)")` produces key `cart.items.count %lld`. The catalog key is `cart.items.count` with no specifier (xcstrings line 4).
- `OrderSummary.swift:11` `Text("order.shipping \(recipient) \(city)")` produces `order.shipping %@ %@`. The catalog key is `order.shipping` (line 86).
- `OrderSummary.swift:12` `Text("order.total \(...)")` produces `order.total %@`. The catalog key is `order.total` (line 109).

As written, these lookups would miss the catalog and show the raw key text with arguments substituted. A build refreshing extraction would typically add the `... %lld` / `... %@ %@` keys as new entries and mark the current ones stale. The `cart.items.count` plural variations would then not be applied at all, which could by itself produce wrong output in every language.

The ticket says English and German look fine, which conflicts with this reading. Possible explanations: the shipped catalog differs from this copy; the keys were renamed after extraction; or the key-with-arguments entries exist in the real project. I cannot resolve this without a build and the extraction diff. Treat it as likely and unverified.

Fix: either rename the catalog keys to `cart.items.count %lld`, `order.shipping %@ %@`, `order.total %@` (the plural variation then attaches to `%lld`), or stop interpolating and use `String(localized:)` / `LocalizedStringResource` with explicit arguments. Use the build's extracted keys as the source of truth and inspect the diff before accepting removed or stale keys.

### 4. Reordered placeholders in the shipping line are fine
- en/de use `%1$@ ... %2$@`; ru (line 104) uses `%2$@ ... %1$@`. Positional specifiers make this legitimate. The comment (line 87) documents which argument is which.
- `check_format_arguments.py` on `order.shipping` and `order.total` for `de` and `ru`: no findings. All signatures are equal (`1: object`, `2: object`; `1: object`).
- Caveat on this check: it validates the declared types only, not the actual arguments or the wording. It also only applies if the real call-site key matches (finding 3).

Linguistic concern (needs a Russian reviewer, not a technical defect): "Доставка в город %2$@ для %1$@" puts the recipient after "для", which requires the genitive case. Interpolating a name in the nominative produces "для Иван" instead of "для Ивана". Names cannot be inflected by format strings. A neutral phrasing such as "Получатель: %1$@. Город доставки: %2$@" avoids the problem. Also "в город" before a city name is fine only for cities, not villages or districts; the neutral form avoids that too.

### 5. Other items, lower priority
- `order.total` (OrderSummary.swift:12): the amount is preformatted with `.formatted(.currency(code:))` and then interpolated as a String (`%@`). It uses the current formatting locale and the item's currency code, so currency meaning is not changed by locale. It is fine, but `Text(total, format: .currency(code:))` would be more consistent with `CartView.swift:17`. The mixed-currency cart case is not handled in the header or total; I could not tell whether a cart can mix currencies from this source.
- `Text(item.name)` and `Text(recipient)` / `city` are verbatim data, correctly not localized.
- Text expansion: "Оформить заказ" (14 chars) vs "Check out" (9 chars) sits in a `.borderedProminent` Button with no width constraint (CartView.swift:21-22). Probably fine, but Dynamic Type at accessibility sizes and the header plus price `HStack` (lines 14-18, long names plus long currency strings, no `lineLimit`/`layoutPriority`) are unchecked. Russian text is the expansion-prone locale here.
- No RTL locale is shipped; no directional concerns beyond default semantic layout (the views use `.leading` alignment and `Spacer`).
- Not visible in this input: InfoPlist.strings / permission strings, extensions, stringsdict, localized assets, app icon/screenshot text, or `knownRegions` in the project file. I could not review them.

## What I could not verify from source
- Extraction state and actual runtime keys (finding 3): needs a build and a look at the catalog diff.
- The actual rendering for 1, 2, 5, 11, 21, 22 in ru (needs a simulator run with app language ru and a variety of cart sizes), plus formatting locale/region varied independently from app language.
- Russian wording quality, the recipient-case issue, and sign-off on the new plural strings (translator input).
- Layout at largest accessibility sizes in ru and de.
- Whether the ticket's "5 items" example is accurate (it should already be correct by fallback).

## Recommended changes, in order
1. Add `few` and `many` to `ru` for the cart header (xcstrings lines 43-60), pending reviewer confirmation of the wording.
2. Reconcile catalog keys with the extracted call-site keys (`%lld`, `%@ %@`, `%@`), by building and inspecting the extraction diff.
3. Have a Russian reviewer rework the shipping line to avoid the inflection problem; keep the positional placeholders either way.
4. Run ru plural boundary checks (0, 1, 2, 4, 5, 11, 12, 21, 22, 100, 101) and Dynamic Type checks.

Tool notes: `catalog_inventory.py` for `de`, `ru` returned no findings (it does not check plural categories or placeholders). `check_format_arguments.py` for `order.shipping` and `order.total` returned no findings and equal signatures.
