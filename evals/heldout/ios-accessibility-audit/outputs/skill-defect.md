# Accessibility source review: Checkout cart screen

Scope: primary flow is "review cart, adjust quantities or remove an item, pay". Read-only source review of CheckoutView.swift, CartRow.swift, CartModels.swift, Localizable.xcstrings and CONTEXT.md. Nothing was built or run.

## Finding 1 (blocks completion): the three icon-only row buttons have no accessible name
Evidence, CartRow.swift:
- L18-21 `Button { store.decrement(item) } label: { Image("ic_minus")... }`
- L26-29 `Button { store.increment(item) } label: { Image("ic_plus")... }`
- L33-36 `Button(role: .destructive) { store.remove(item) } label: { Image("ic_remove")... }`

None has `.accessibilityLabel`. The `Image("name")` initializer is not given a label or marked decorative. SwiftUI's fallback for a catalog image is its asset name, unless the catalog entry has an accessibility label set (the catalog was not provided). The likely spoken output is something like "ic minus, button", which fits the tester's report that they could not tell what the controls do. The `.destructive` role does not speak a name or a warning on its own. The rest of the screen uses `Text`, which is why it reads fine.

Fix (smallest change that addresses the cause): label each button, and put the item name in the label so each row is distinguishable.
```swift
Button { store.decrement(item) } label: { Image("ic_minus").frame(minWidth: 44, minHeight: 44) }
    .accessibilityLabel("Decrease quantity of \(item.name)")
Button { store.increment(item) } label: { ... }
    .accessibilityLabel("Increase quantity of \(item.name)")
Button(role: .destructive) { store.remove(item) } label: { ... }
    .accessibilityLabel("Remove \(item.name) from cart")
```
Optionally also mark the images `Image(decorative:)` style (or `.accessibilityHidden(true)`) so the asset name cannot leak in. Alternatively, use `Label("Remove", image: "ic_remove").labelStyle(.iconOnly)`, which gives a name and an icon in one place.

## Finding 2: localization of the new labels
Localizable.xcstrings (L4-8) has only "Cart", "Pay now" and "Total", each with an empty entry. Any new label must be added to the catalog. Interpolated literals such as `"Remove \(item.name) from cart"` become the key `"Remove %@ from cart"`. Add the keys with the `%@` placeholder and a translator comment. English only today, but the keys should still exist so Xcode extraction does not leave them as stale or missing. Use `Text`/`LocalizedStringKey` overloads of `accessibilityLabel` (the string-literal form is localized automatically); do not build labels with `String(format:)` from non-localized fragments.

## Finding 3 (moderate): quantity is a separate, unlabeled element, and the stepper is split into three stops
- L23 `Text("\(item.quantity)")` reads only as a bare number, with no link to the item or to the +/- buttons. Per row, VoiceOver has to go through name, price, minus, number, plus, remove with no grouping context.
- Decrement is a silent no-op at quantity 1 (CartModels.swift L27 `if items[i].quantity > 1`). The button still reads as enabled and does nothing, so a VoiceOver user gets no feedback. This is a state cue that is not exposed.

Suggested change, a judgment call for the team: prefer a native `Stepper` (or a custom control with `.accessibilityElement(children: .ignore)`, `.accessibilityValue("\(item.quantity)")` and `.accessibilityAdjustableAction`), which gives a single adjustable element ("Quantity, 2, adjustable"). The remove action can stay a separate button, or become a `.accessibilityAction(named:)` on the row. If you keep the buttons, `.disabled(item.quantity <= 1)` on the minus button, or make it remove the item, so the state is exposed through the disabled trait. If the row is ever grouped with `.accessibilityElement(children: .combine)`, verify that all three actions are still reachable (a grouped row can hide them).

## Finding 4 (likely functional bug, not verifiable from source): multiple Buttons in a List row
CartRow is used inside `List` (CheckoutView.swift L14-18) with the default (automatic) button style. In a List row, several default-style Buttons commonly make the whole row a single tap target that can fire all of them at once, which affects touch and VoiceOver double-tap alike. The usual fix is `.buttonStyle(.borderless)` (or `.plain`) on each button or on the HStack. Confirm on a device. This is an inference from known SwiftUI behavior, not demonstrated here.

## Finding 5 (low/needs verification): Dynamic Type
- Frames use `minWidth: 44, minHeight: 44`, so the tap targets meet the 44pt hit-region minimum. This is acceptable for touch.
- Text uses semantic fonts (`.headline`, `.body`, `.title3.bold()`), so it scales. There are no fixed heights on text.
- Possible issues at the AX5 size: the name/price HStack (CartRow.swift L9-15) has no wrapping fallback, so long item names may compress the price; the `Image` assets have no `.resizable()`, so the icons stay fixed-size while the numeral text grows (visual mismatch, not a barrier). The 44pt fixed-ish control row (L17-37) has `Spacer()` and three controls, which probably fits at 375pt width. Consider `ViewThatFits` or `@Environment(\.dynamicTypeSize)` to stack name and price at accessibility sizes.
- Total + Pay area (CheckoutView.swift L21-35) sits outside the List, so at large sizes it may take much of the screen and leave little room for the List. Check this at the largest size.

## Other observations (no change needed)
- "Pay now" Button has a `Text` label and `minHeight: 44`; the Total/price texts use `Text` with currency format. They already expose a name and value natively.
- After `remove`, the removed row disappears; VoiceOver focus may land on an unpredictable element. Check this at runtime (see below).
- Color contrast: `.borderedProminent` and the destructive tint rely on system colors, and the icons' colors are unknown (assets not included).

## Could not verify from source alone
- The actual spoken output (including whether the asset catalog sets accessibility labels or what the fallback reads, for example "ic minus").
- VoiceOver focus order and focus after removing a row or decrementing.
- Whether the row's buttons fire together in the List (Finding 4).
- Actual clipping/overlap at the largest accessibility size; contrast of the PNG/PDF artwork (catalog missing, rendering mode template vs original).
- Accessibility Inspector audit results (nobody has run one yet), and Voice Control / Switch Control reachability of the buttons by name.

Suggested verification on a physical device or simulator: open the cart with 2+ items; swipe through a row with VoiceOver and listen to each control; activate each; remove an item and note where focus lands; set the text size to the largest accessibility size on a narrow phone and confirm the whole row and the Pay button are reachable; use Voice Control "Show names" to confirm the labels; then run `performAccessibilityAudit()` (or the Inspector) on the populated cart. These are pending, not passed.

## Priority of changes
1. Add `accessibilityLabel` (with item name) to the three icon buttons, and add the keys to Localizable.xcstrings.
2. Expose quantity as a value / adjustable control and disable or handle minus at quantity 1.
3. Apply `.buttonStyle(.borderless)` to the row's buttons and confirm independent activation.
4. Check Dynamic Type at AX sizes and focus after removal on a device.
