# Accessibility review: checkout cart screen (read-only, source only)

Files reviewed: CONTEXT.md, CartRow.swift, CheckoutView.swift, CartModels.swift, Localizable.xcstrings. Nothing was built or run.

## Summary
The tester's report matches the source. The three row controls (decrease, increase, remove) are image-only buttons with no accessibility label, hint or value. Everything else on the screen uses plain `Text` or text-labelled controls, which is why it reads fine. There are also secondary issues around the quantity readout, touch handling of multiple buttons in a List row, Dynamic Type behaviour, and localization of the strings that must be added.

## Findings

### 1. High: icon-only buttons have no accessible name (the reported bug)
- CartRow.swift:18-21 `Button { store.decrement(item) } label: { Image("ic_minus") ... }`
- CartRow.swift:26-29 `Image("ic_plus")`
- CartRow.swift:33-36 `Image("ic_remove")` (also `role: .destructive`)

None has `.accessibilityLabel`, and the images are custom assets, not SF Symbols, so there is no system-provided meaning. A SwiftUI `Image("name")` falls back to using the asset name as its label, so VoiceOver most likely announces something like "ic minus, button". That would match "had to guess". Which text it announces depends on the asset catalog, which is not included. It is not meaningful to users either way.

Change: add a localized label to each button, ideally with the item name, since the three rows' controls are otherwise identical:
- "Decrease quantity of \(item.name)"
- "Increase quantity of \(item.name)"
- "Remove \(item.name)"

Put `.accessibilityLabel(...)` on the Button, not the Image. Because the icons are purely visual, also add `.accessibilityHidden(true)` to the Image, or label the Button so the Image does not add a duplicate.

### 2. Medium: quantity is an unlabelled bare number
- CartRow.swift:23-24 `Text("\(item.quantity)")`

VoiceOver reads just "2" with no context, and it sits between the two buttons as a separate stop. Better: a combined element, for example `.accessibilityLabel("Quantity").accessibilityValue("\(item.quantity)")`. Even better, expose the stepper as one adjustable element using `accessibilityElement(children: .ignore)`, `.accessibilityAdjustableAction`, and a value. Alternatively use a native `Stepper`. Setting the value this way also means VoiceOver announces the new number after each change.

### 3. Medium: decrement at quantity 1 silently does nothing
- CartModels.swift:27 `if items[i].quantity > 1 { ... }`
- CartRow.swift:18 the button is not disabled at 1.

Users get no visual or spoken feedback. Use `.disabled(item.quantity <= 1)`, which gives VoiceOver the "dimmed" trait. Also make sure the disabled-state artwork looks different.

### 4. Medium (cannot confirm from source): multiple buttons in one List row
- CheckoutView.swift:14-18 `List { ForEach ... CartRow }` and CartRow.swift:18, 26, 33 (three `Button`s with the default style).

In a SwiftUI `List`, a row holding more than one default-style `Button` is known to treat the whole row as tappable, so tapping anywhere can trigger all the buttons (decrement, increment and remove). This affects every user, and VoiceOver activation too. Add `.buttonStyle(.borderless)` (or `.plain`) to each button. I could not verify this on a device. Treat it as a likely issue to test.

### 5. Low/Medium: row structure for VoiceOver
Each row is 6 separate stops (name, price, minus, count, plus, remove). Consider grouping the name and price into one element (`.accessibilityElement(children: .combine)` on the first HStack, CartRow.swift:9-15) so it reads "Espresso, $4.50". Alternatively expose the whole row with a combined label ("Espresso, quantity 2, $9.00") plus `accessibilityAction` entries for increase, decrease and remove (shown in the VoiceOver Actions rotor). Pick one pattern and keep it consistent.

### 6. Low: focus after removal
CartRow.swift:33 / CartModels.swift:30-32. After a row is deleted, VoiceOver focus is lost. Consider moving focus (`@AccessibilityFocusState`) or posting an announcement such as "Espresso removed". A destructive action without a confirmation or undo is also a risk for users who trigger it by accident, which is easier to do with the multiple-button issue in finding 4.

### 7. Dynamic Type
Positive: text uses semantic styles (`.headline`, `.body`, `.title3`; CartRow.swift:11, 14, 24; CheckoutView.swift:24, 27), and the Pay button uses `minHeight: 44` (CheckoutView.swift:31), so it can grow. Issues and unknowns:
- CartRow.swift:20, 28, 35 use fixed `minWidth: 44, minHeight: 44` frames. This meets the minimum touch target, but the icons do not scale with text size. Use `@ScaledMetric` for the frame size, and give the asset images "Preserve Vector Data / Scales" or `.resizable().scaledToFit()` with a scaled frame, so they follow Dynamic Type. I could not check the asset sizes.
- CartRow.swift:9-15: name and price share an HStack with no wrapping fallback. At accessibility sizes long names will wrap heavily or the price may truncate. Consider `ViewThatFits` or switching to a VStack when `dynamicTypeSize.isAccessibilitySize`.
- CartRow.swift:17-37: the control row (two buttons, count, spacer, remove) is fixed horizontal. It will likely still fit, but verify at AX5.
- CheckoutView.swift:21-35: the Total row and Pay button sit outside the List in a non-scrolling footer. At accessibility sizes that footer takes a large share of the screen and the list area shrinks. Not verifiable from source. Test at AX5 and consider moving the footer into `safeAreaInset` with a size cap, or making the whole screen scroll.
- CheckoutView.swift:23 and 26: Total label/value use `.title3.bold()` and could mark the Total as a header or combine as one element ("Total, $12.00").

### 8. Localization of the new strings
Localizable.xcstrings contains only "Cart", "Pay now" and "Total" (lines 5-7), with empty values. Any new label strings need entries added, including interpolation placeholders (for example "Decrease quantity of %@"). A string literal passed to `.accessibilityLabel` is a `LocalizedStringKey` and will be looked up, but a runtime-built `String` will not, so use literals or `String(localized:)`. Related: currency is hard-coded to "USD" (CartRow.swift:13, CheckoutView.swift:26), which is a localization issue rather than an accessibility one. VoiceOver reads currency text correctly in the current style.

## What I could not verify from source
- The exact text VoiceOver reads for the image buttons (depends on asset catalog entries, which are not included; asset-level accessibility labels are not set via the catalog in Xcode, so I assume none).
- Whether the multi-button List row issue (finding 4) actually triggers on iOS 17 for this layout.
- Visual state of icons when disabled, contrast of icon artwork, the size and scaling of the artwork, and real layout at accessibility Dynamic Type sizes.
- Rotor/focus order and Switch Control / Voice Control behaviour (Voice Control also needs labels; the label fix helps it).
- That nothing is overridden elsewhere in the app (modifiers on parent views, other files not provided).
- Nobody has run the Accessibility Inspector (CONTEXT.md:11); the audit and a real VoiceOver pass should be done after the changes.

## Suggested change (sketch)
```swift
Button { store.decrement(item) } label: {
    Image("ic_minus").frame(minWidth: 44, minHeight: 44).accessibilityHidden(true)
}
.buttonStyle(.borderless)
.disabled(item.quantity <= 1)
.accessibilityLabel("Decrease quantity of \(item.name)")
// likewise: "Increase quantity of \(item.name)", "Remove \(item.name)"
```
Add the matching keys to Localizable.xcstrings, and give the quantity Text an accessibility label/value.
