# Localization review: Kiosk (en, de, ru)

Files reviewed: Localizable.xcstrings, CartView.swift, OrderSummary.swift, CONTEXT.md. Read-only; nothing built or run.

## Findings

### 1. [High, confirmed from source] Russian `cart.items.count` is missing the `few` and `many` plural categories
Localizable.xcstrings lines 43-60: the `ru` plural variation defines only `one` ("%lld товар", line 49) and `other` ("%lld товаров", line 55). CONTEXT.md line 10 states Russian needs one, few, many, other.

Effect, by CLDR rules for integers:
- one: n%10==1 and n%100!=11 (1, 21, 31...). Correct form is "товар".
- few: n%10 in 2..4 and n%100 not in 12..14 (2, 3, 4, 22...). Correct form is "товара".
- many: 0, 5-20, 25-30... Correct form is "товаров".
- other: only fractions in Russian, not reached by an Int count.

With only `one` and `other`, the runtime falls back to `other` for few and many. So 2 reads "2 товаров" (should be "2 товара"). 5 reads "5 товаров", which is correct only by accident because the `other` text happens to equal the `many` form. This matches the support ticket ("2 or 5 items look ungrammatical"). The 5 case is slightly unclear: by my reading it renders correctly, so the ticket's example for 5 may be imprecise. QA should check 2, 3, 4, 22, 0, 11 and 21. 21 uses the `one` form, which the current file handles correctly.

Fix: add `few` and `many`, keep `one` and `other`:
- one: "%lld товар"
- few: "%lld товара"
- many: "%lld товаров"
- other: "%lld товара" (the usual Russian convention for fractional values). Translator input needed for it.

Xcode normally shows the needed variants per locale in the catalog editor. This catalog was apparently authored or edited by hand, or with the variants removed. Because states are "translated" rather than "needs_review", Xcode will not flag the gap, so it is worth a catalog-completeness check in CI.

### 2. [Low, confirmed] German plural has identical `one` and `other` strings
Lines 28-39: both are "%lld Artikel". This is grammatically right, since "Artikel" is invariant, and it is harmless. Both variants are required by CLDR for de, so no change is needed. A translator comment could say it is intentional.

### 3. [Not a bug, confirmed] Reordered placeholders in `order.shipping`
Lines 86-108. English and German use `%1$@ in %2$@` (recipient, then city). Russian uses `%2$@ ... %1$@` (line 104: "Доставка в город %2$@ для %1$@"). Positional specifiers are the correct mechanism for reordering, and each argument is used exactly once. The Swift side, `Text("order.shipping \(recipient) \(city)")` (OrderSummary.swift:11), produces two `%@` arguments in the order recipient, city. That matches the comment on line 87. So the answer to QA is no, this is not a problem.

Caveats:
- The Russian text uses the city and recipient as bare nominative strings. "для %1$@" ("for X") needs a dative-case name in correct Russian, so a name like "Иван Петров" would read as ungrammatical ("для Иван Петров" instead of "для Ивана Петрова"). "в город %2$@" is acceptable with a nominative city name ("в город Москва"). The recipient case issue is a translator and product decision. Options are to rephrase to avoid declension (for example "Получатель: %1$@, город: %2$@") or accept it. Not verifiable from source.
- The wording changes the meaning slightly ("Shipping to X in Y" versus "Delivery to city Y for X"). It is acceptable but should be translator-confirmed.

### 4. [Low, source-level] Currency and number formatting
- CartView.swift:17 and OrderSummary.swift:12 use `.currency(code:)`, which formats using the current locale. That is correct for separators and symbol placement. Note `format:` is locale-aware, but `total.formatted(...)` at OrderSummary.swift:12 is evaluated eagerly into a String before interpolation. It uses the environment-agnostic `Locale.current`, not the SwiftUI `\.locale` environment, so it will not follow a `.environment(\.locale, ...)` override (for example in previews or in an in-app language picker). Preferable is `Text("order.total \(total, format: .currency(code: currencyCode))")`, which uses the view's environment locale. The interpolation becomes a `%@` placeholder, which matches the catalog entry. Moderate impact only if the app overrides locale in-process.
- The cart item price is formatted correctly via `Text(_, format:)` (CartView.swift:17).
- With a `Decimal` price and a per-item `currencyCode`, there is no source of truth issue visible. Could not verify.

### 5. [Low, source-level] Plural argument type
CartView.swift:10: `Text("cart.items.count \(items.count)")`. `items.count` is `Int`, which produces `%lld`. That matches the catalog's `%lld`. The key is a LocalizedStringKey of the form "cart.items.count %lld", while the catalog key is "cart.items.count" with no `%lld`. The extracted key from this interpolation would be "cart.items.count %lld". The catalog key on line 4 is "cart.items.count" without the argument placeholder. As written, the lookup key string will be `cart.items.count %lld`, which will not match `cart.items.count`. Result: the plural variations are probably never used and the raw key text would be shown in all locales. This contradicts the ticket (English and German "look fine"), so I cannot tell whether the catalog was hand-edited after extraction. This is worth verifying with a build. If the key needs a specifier, it should be renamed to "cart.items.count %lld" in the catalog. The same applies to `order.shipping` (code: "order.shipping %@ %@", catalog: "order.shipping") and `order.total` (code: "order.total %@"). Verify in a build and simulator run, because Xcode normally extracts keys with the specifiers. Whether the catalog key is wrong is a real doubt, because the ticket says English and German work.

### 6. [Info] Coverage
All four keys (cart.items.count, cart.checkout, order.shipping, order.total) have en, de and ru entries marked "translated". Every key has a comment, which is good practice. No missing locales, no `needs_review` or `stale` states.

Not covered by the catalog: `item.name` (CartView.swift:15) is `Text(item.name)` with a String, so it is not localized, which is intended for product data. `recipient` and `city` are user data.

### 7. [Info] Layout risks in shipped locales
- Russian strings are longer: "Оформить заказ" (14 characters) versus "Check out" (9) on a `.borderedProminent` button (CartView.swift:21-22), "Доставка в город ... для ..." in OrderSummary.swift:11 with no `lineLimit` set, so it wraps rather than truncates. The header `Text` at CartView.swift:10 may wrap on small devices. Plural forms like "21 товаров" are not longer than expected.
- `HStack { Text(item.name); Spacer(); Text(price) }` (CartView.swift:14-18) has no minimum scale or layout priority. A long product name plus a long German or Russian currency string (for example "1 234,56 €") could squeeze. Needs simulator verification with long names and larger Dynamic Type.

## Not verifiable from source alone
- Actual rendered strings and the key-matching question in finding 5 (needs a build and a run, or inspecting the extracted catalog in Xcode).
- Final Russian wording for the `other` category and the recipient dative-case issue (translator input).
- Truncation and wrapping, Dynamic Type behavior and visual layout in ru and de (simulator).
- Whether the app overrides locale in-process (affects finding 4).
- The test matrix for ru plurals: run 0, 1, 2, 4, 5, 11, 12, 21, 22, 25 after the fix.

## Recommended changes (priority order)
1. Add `few` and `many` (and keep `one`, `other`) to the ru plural variation for `cart.items.count`. This resolves the support ticket.
2. Confirm the catalog keys match the code's interpolated keys with a build (finding 5), and rename keys if not.
3. Use `Text(_, format:)` for the total so it follows the environment locale.
4. Ask the translator to review the Russian shipping line (declension) and the `other` plural form.
5. Add a CI check that verifies required CLDR plural categories per locale, since the "translated" state hides the gap.
6. Test long strings in ru and de at larger Dynamic Type.
