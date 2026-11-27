# Accessibility source review: Cart screen (CheckoutView / CartRow)

Scope: primary flow is "review the cart, adjust quantity or remove an item, then pay". This is a source-only review of `CheckoutView.swift`, `CartRow.swift`, `CartModels.swift`, `Localizable.xcstrings` and `CONTEXT.md`. Nothing was built or run. No VoiceOver, Dynamic Type or Accessibility Inspector checks were performed, so all of those are pending, not passing.

## Summary

The reported symptom is that a VoiceOver tester cannot tell what the row controls do. The source does not support that for the three buttons. Each button has an explicit `accessibilityLabel` that overrides its unlabeled custom image (`CartRow.swift:22, 32, 41`). The labels "Decrease quantity", "Increase quantity" and "Remove <name> from cart" are all present in `Localizable.xcstrings:6,7,9`.

So the cause of the report is not visible in source. Candidates are below, with the one thing to check first.

- **Stale or different build.** The tester may have run a build from before the labels were added. Confirm the tester's build contains `CartRow.swift` lines 22, 32 and 41.
- **Ambiguous labels.** The labels exist but are context-free: "Decrease quantity" and "Increase quantity" do not say which item they affect (Finding 1). With several rows this is probably what the tester meant by guessing.
- **Value announced as part of the label.** The `accessibilityValue` on the quantity buttons makes the spoken output confusing (Finding 2).
- **Tap behaviour in a List row.** Several default-style buttons in one List row may misbehave (Finding 3). That is a touch problem and would not explain a spoken-label complaint.

I could not reproduce or confirm any of these from source alone.

## Findings (ordered by impact on completing the task)

### 1. Quantity buttons do not name the item they act on (likely the reported issue)
`CartRow.swift:22` and `:32` use fixed labels "Decrease quantity" and "Increase quantity". In a cart with several rows, VoiceOver users hear identical strings on every row. This includes the rotor/Item Chooser list, where each element is read out of its row context. Only the remove button includes the item name (`:41`), so the three controls are inconsistent.

Fix: include the item name, for example "Decrease quantity of \(item.name)" and "Increase quantity of \(item.name)". Add matching `%@` keys to `Localizable.xcstrings`.

Better still, replace the three-element cluster with one adjustable element, or a native `Stepper`:
- Group the minus, count and plus into one element labeled with the item name.
- Expose the quantity as its value.
- Use `.accessibilityAdjustableAction` for increment and decrement.

The `Stepper` form also removes the next finding.

### 2. Quantity is exposed redundantly and the value is attached to the wrong kind of element
`CartRow.swift:23` and `:33` set `accessibilityValue(Text("\(item.quantity)"))` on each button. The plain `Text("\(item.quantity)")` at `:25-26` is also its own element. This matches the reviewer note in CONTEXT.md.

For the quantity, VoiceOver traversal is therefore likely: "Decrease quantity, 2, button", "2", "Increase quantity, 2, button". The value on a button reads as if the button's own state were "2". The user hears the same number three times per row, and it is unclear whether "2" is the quantity or the value of the control.

Fix: pick one source of truth. Either hide the standalone Text from accessibility (`.accessibilityHidden(true)`) and put the value on a single combined/adjustable element, or drop the value from both buttons and keep the Text. Whether a value change after tapping is spoken depends on VoiceOver behaviour I cannot verify from source.

### 3. Multiple default-style Buttons in a List row (needs device verification)
`CheckoutView.swift:14-18` places `CartRow` in a `List`. `CartRow.swift:18, 28, 37` use three plain `Button`s with no `.buttonStyle`. In a List row, default-style buttons are known to make the whole row act as the tap target, and tapping one can fire the actions of all the buttons in that row. Here that would mean a tap on plus could also decrement and remove.

I could not confirm this on iOS 17 from source. It is a high-severity touch and switch-access risk if true.

Fix: add `.buttonStyle(.borderless)` or `.buttonStyle(.plain)` to each row button, then verify with a tap test and with VoiceOver activation.

### 4. Decrease at quantity 1 is a silent no-op
`CartModels.swift:27` ignores the decrement when the quantity is 1, but the button stays enabled and gives no feedback (`CartRow.swift:18-23`). A VoiceOver user activates it and hears nothing change.

Fix: `.disabled(item.quantity <= 1)` so VoiceOver announces "dimmed". Keep the separate Remove button as the way to delete the item.

### 5. Remove has no confirmation, no announcement, and focus is not managed
`CartRow.swift:37` and `CartModels.swift:30-32` delete the row immediately. When the focused row is removed, VoiceOver focus may land somewhere unexpected or be lost. This is unverified.

Fix: post an `AccessibilityNotification.Announcement("<name> removed from cart")`. Consider an undo path, and test where focus lands afterward.

### 6. Dynamic Type risks (not measured)
- **Fixed icon frames.** `CartRow.swift:20, 30, 39` use `.frame(minWidth: 44, minHeight: 44)`. The 44pt hit region is good at default size and a custom `ic_*` image does not scale with text. Fix: use `@ScaledMetric` for the frame size and the image, and test the largest accessibility size.
- **Cramped HStacks.** `CartRow.swift:9-15` puts a `.headline` name, a Spacer and the price in one HStack, and `:17-42` fits two 44pt buttons, a count, a Spacer and a third 44pt button, all with 16pt spacing, in one HStack. On a narrow screen at AX sizes, these may truncate or overflow horizontally. Fix: use `ViewThatFits` or switch to a vertical layout when `dynamicTypeSize.isAccessibilitySize`.
- **Fixed bottom bar.** `CheckoutView.swift:21-35` keeps the Total and Pay now button outside the scrolling List. At the largest sizes this bar (title3 bold total, 44pt minimum button, padding) takes a large share of the screen and cannot scroll, leaving little room for the list. Not measured. Test on the smallest supported device, and consider moving the total into the scrollable content at accessibility sizes.

### 7. Smaller points
- **Image rendering and contrast.** The `ic_*` assets are not included, so I could not verify their rendering mode (template or original), their contrast against the row background in light and dark, or whether they have a visible destructive tint. `Button(role: .destructive)` with an `Image` label (`CartRow.swift:37`) may not tint the image as a text label would.
- **Hard-coded currency.** `.currency(code: "USD")` in `CheckoutView.swift:26` and `CartRow.swift:13` is not locale-aware. It is spoken as a currency amount, which is fine for VoiceOver, but it will be wrong for non-USD users.
- **Localization.** `Localizable.xcstrings` has keys only, with no translations (English only, as stated). Interpolated labels use `LocalizedStringKey`, so `Remove %@ from cart` matches. New labels from Finding 1 need new keys.
- **Pay now.** `CheckoutView.swift:29-33` is a standard Button with text and a 44pt minimum height. It is fine.
- **Nav title and list.** `navigationTitle("Cart")` and the Total row read as text. The total has no heading trait or grouping, which is minor.

## What I could not verify from source alone
- Actual VoiceOver spoken output, traversal order, rotor behaviour, and focus after remove or decrement. All pending.
- Whether the tester's build matches this source.
- Whether tapping one row button triggers the others (Finding 3).
- Dynamic Type clipping and overlap, including the fixed bottom bar. All pending.
- Color contrast and rendering of `ic_minus`, `ic_plus` and `ic_remove`, since the asset catalog is not included.
- Accessibility Inspector or `performAccessibilityAudit()` results. Nobody has run them on this screen, and this review is not a substitute for them.

## Suggested checks on device
1. Cart with 3 items, VoiceOver on. Swipe through one row and record what is spoken for each element. Confirm labels and values as in Findings 1 and 2.
2. Tap each row button with a finger and with VoiceOver double-tap. Confirm only one action fires (Finding 3).
3. Decrement at quantity 1, then remove an item. Note feedback and where focus lands.
4. Set Dynamic Type to the largest accessibility size on the smallest supported iPhone. Check that the row, Total and Pay now are all readable and reachable.
5. Run `performAccessibilityAudit()` in a UI test after the cart is loaded.

## Recommended changes (smallest first)
1. Add `.buttonStyle(.borderless)` to the three row buttons (`CartRow.swift:18, 28, 37`).
2. Include the item name in the increase/decrease labels and add the string keys.
3. Remove the duplicated quantity: value on one element only, or use an adjustable `Stepper`-style element.
4. Disable the decrement button at quantity 1.
5. Announce removal.
6. Make icon sizes and the row layout adapt to Dynamic Type.

Files reviewed:
- `/private/tmp/claude-501/-Users-tudor--claude-spares-spare-tWNwJp/80e4c058-a3b7-4839-b789-80c7c486b345/scratchpad/evalall/ios-accessibility-audit/skill-clean/CartRow.swift`
- `/private/tmp/claude-501/-Users-tudor--claude-spares-spare-tWNwJp/80e4c058-a3b7-4839-b789-80c7c486b345/scratchpad/evalall/ios-accessibility-audit/skill-clean/CheckoutView.swift`
- `/private/tmp/claude-501/-Users-tudor--claude-spares-spare-tWNwJp/80e4c058-a3b7-4839-b789-80c7c486b345/scratchpad/evalall/ios-accessibility-audit/skill-clean/CartModels.swift`
- `/private/tmp/claude-501/-Users-tudor--claude-spares-spare-tWNwJp/80e4c058-a3b7-4839-b789-80c7c486b345/scratchpad/evalall/ios-accessibility-audit/skill-clean/Localizable.xcstrings`
