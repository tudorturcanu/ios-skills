# Localization review: Kiosk (en source; en, de, ru)

Source-only review. Nothing was built or run. I ran the guidance's `catalog_inventory.py` and `check_format_arguments.py` (read-only) on `Localizable.xcstrings`.

## Summary

- The Russian plural entry for `cart.items.count` is correct for all four CLDR categories. The catalog does not explain the ticket's "2 or 5 items" symptom.
- The reordered placeholders in `order.shipping` are valid and are not a problem.
- The most likely real defect is a key mismatch between the call sites and the catalog (finding 1). It would affect every locale, not only Russian.
- The ticket's premise that English and German look fine does not fit what the source shows. This needs a runtime check.

## Findings

### 1. Catalog keys probably do not match the keys SwiftUI generates (high likelihood, needs a build to confirm)

- `CartView.swift:10`: `Text("cart.items.count \(items.count)")` creates a LocalizedStringKey. With an `Int` interpolation the key is `cart.items.count %lld`.
- `OrderSummary.swift:11`: `Text("order.shipping \(recipient) \(city)")` produces the key `order.shipping %@ %@`.
- `OrderSummary.swift:12`: `Text("order.total \(...)")` produces the key `order.total %@`.
- `Localizable.xcstrings:4, 98, 121` define the keys `cart.items.count`, `order.shipping` and `order.total`, with no argument suffix.
- A lookup of `cart.items.count %lld` finds no entry, so the UI would show the raw key text. Xcode extraction would also add new keys with the suffix and mark the old ones stale.
- Why it matters: the plural variations, the ru reordering and the translations would never be used.
- Only `cart.checkout` (`CartView.swift:21`) is a plain literal and matches its catalog key.
- Fix, either way:
  - Rename the catalog keys to the generated form (`cart.items.count %lld`, `order.shipping %@ %@`, `order.total %@`), preserving comments and translations. The simplest route is to build in Xcode and let extraction create them, then migrate the translations and review the diff before removing stale keys.
  - Or use explicit keys: `Text(LocalizedStringResource("cart.items.count", defaultValue: "\(items.count) items"))`. The same applies to the other two.
- Not verified: the actual runtime lookup, and whether the catalog has been refreshed by a build elsewhere. Only this stored catalog was seen.

### 2. Russian cart-count plural (`Localizable.xcstrings:43-72`): correct, no defect found

- `one` is "%lld товар" (1, 21, 31, ...).
- `few` is "%lld товара" (2-4, 22-24, ...).
- `many` is "%lld товаров" (0, 5-20, 25-30, ...).
- `other` is "%lld товара" (fractions only).
- All four categories are present and `state` is `translated`.
- So 2 gives "2 товара" and 5 gives "5 товаров", which are grammatical.
- `other` shares its wording with `few`. That is acceptable, because the genitive singular is correct for fractions and `other` is never reached for an Int.
- If the Russian header is wrong in the app, the cause is outside this entry. Candidates:
  - The key mismatch above, with fallback text shown.
  - A stale or older catalog or build.
  - The device or app language not being Russian (for example, only the region set to Russia).
  - Russian missing from the project's localizations or `knownRegions`, so the `ru` entries are not selected.
  - A different string being shown.
- Things to check outside the source: the shipped `.strings`/`.stringsdict` or compiled catalog in the built `ru.lproj`, the project's localization list, and a reproduction at counts 1, 2, 5, 11, 21 and 22.
- Not verified from source: translation quality (a fluent reviewer is needed).

### 3. `order.shipping` placeholder reordering is valid (`Localizable.xcstrings:98-120`)

- en and de use `%1$@ ... %2$@`.
- ru uses `%2$@ ... %1$@`: "Доставка в город %2$@ для %1$@".
- The checker found identical signatures (both objects) with no findings for de and ru.
- Explicit positions are the correct way to reorder, so QA need not worry about the reordering.
- Linguistic concern for a translator (not verifiable here): "для %1$@" needs the recipient in the genitive case. A name interpolated in nominative form ("для Иван") will read ungrammatically. Options are to reword so that no case is needed (for example "Получатель: %1$@, город: %2$@") or to accept the limitation.

### 4. German plural (`Localizable.xcstrings:25-42`)

- `one` and `other` are both "%lld Artikel". The two forms are identical, so there is no defect (Artikel is invariant). Keeping both variants is correct, as German uses one and other.
- Zero ("0 Artikel") reads fine.

### 5. Currency and number formatting

- `CartView.swift:17`: `Text(item.price, format: .currency(code: item.currencyCode))` uses the ISO code per item, so the monetary meaning is preserved, and the display follows the environment locale. This is good.
- `OrderSummary.swift:12`: `total.formatted(.currency(code: currencyCode))` runs eagerly into a `String`, then is interpolated as `%@`. This uses `Locale.current`, not the SwiftUI environment `\.locale`.
  - Impact: a `.environment(\.locale, ...)` override, previews, or a mismatched app language and region would not affect this line.
  - Suggested change: `Text(total, format: .currency(code: currencyCode))` inside a composed layout, or `.formatted(.currency(code:).locale(locale))` with `@Environment(\.locale)`.
  - Needs a run with the app language and formatting region varied independently.
- A `Decimal` formatted this way is acceptable. The key `order.total` then takes a `%@` string argument, as the comment says.

### 6. Other observations

- Catalog hygiene:
  - No entry carries an `extractionState`.
  - Comments are present on all four entries. The `cart.checkout` and `order.total` comments are adequate.
  - The inventory script found no missing locales and no non-translated states for de and ru.
  - Nothing is marked `shouldTranslate: false`.
- Layout (needs a simulator run, not verified):
  - `CartView.swift:14-18`: the row `HStack` has no line limit or layout priority. Long product names or long Russian or German currency strings could squeeze the price.
  - The checkout button uses `.borderedProminent`. "Оформить заказ" is about 3x longer than "Zur Kasse", so check button width and wrapping at large accessibility sizes.
  - The header and the shipping line may wrap at large Dynamic Type sizes in the longer ru and de strings.
  - RTL is not a shipped locale, so no RTL check is needed. Leading alignment is already semantic.
- Not covered by the provided files:
  - InfoPlist strings and permission descriptions.
  - Extensions, packages and bundle/table selection (the call sites use the main bundle and default table, which suits this catalog).
  - Localized assets.

## guidance-tool results

- `catalog_inventory.py --locale de --locale ru`: no findings.
- `check_format_arguments.py`:
  - `order.shipping` for de and ru: no findings.
  - `order.total` for de and ru: no findings.
  - `cart.items.count`: reported as manual-review because it uses variations; I inspected it manually (finding 2).

## Could not verify from source (needs build, simulator, or translator)

- Whether findings 1 and 2 happen in the built app: the generated keys, extraction, and the built `ru.lproj` contents.
- The project's localization list and `knownRegions`.
- Rendering at largest accessibility sizes in en, de and ru.
- Translation quality (the genitive name issue in the Russian shipping text, general terminology).
- Formatting behavior with the app language and region varied independently.

## What I would change, in order

1. Align the catalog keys with the call-site keys (or use explicit `LocalizedStringResource` keys), and rebuild to refresh extraction. Review the diff for stale keys before accepting it.
2. Reproduce the Russian header at the counts 1, 2, 5, 11, 21 and 22 on a Russian-language device or simulator, and inspect the built `ru` resource if the text is still wrong. Leave the current `ru` plural variations as they are.
3. Ask a translator about the case problem in the Russian shipping line.
4. Make the total format locale-aware through the environment (`Text(total, format:)`), and add line limits or layout priority to the cart rows.
