# Accessibility source review: checkout cart screen

Scope: CheckoutView.swift, CartRow.swift, CartModels.swift, Localizable.xcstrings, CONTEXT.md. Read-only; nothing built or run.

## Headline

The reported symptom ("cannot tell what the row controls do") is NOT reproduced by the source. All three icon-only buttons already have explicit accessibility labels (CartRow.swift:22, :32, :41), and the labels are in the string catalog (Localizable.xcstrings:6,7,9). A custom, non-SF-Symbol image does not by itself cause unlabeled controls here because `.accessibilityLabel` overrides the image. So I cannot confirm a code defect that explains the tester's report. Possible explanations I cannot distinguish from source: the tester ran a different build than this source; the report is about clarity rather than absence (see findings 1 and 2); or something outside these files (asset catalog, parent containers) interferes. Someone should reproduce it with VoiceOver or the Accessibility Inspector before large changes are made.

## What is already correct (evidence)

- Icon buttons: labels "Decrease quantity", "Increase quantity", "Remove \(item.name) from cart" (CartRow.swift:22, 32, 41). The remove label includes the item name.
- Hit targets: `frame(minWidth: 44, minHeight: 44)` on each icon (CartRow.swift:20, 30, 39); Pay button minHeight 44 (CheckoutView.swift:31).
- Dynamic Type: text uses semantic styles (.headline, .body, .title3.bold) and no fixed font sizes (CartRow.swift:11,14,26; CheckoutView.swift:24,27). Row text has no lineLimit, so it can wrap in the List.
- Localization: interpolated label key "Remove %@ from cart" matches the catalog entry (Localizable.xcstrings:9). Empty `{}` entries with source language en fall back to the key, which is fine for English.

## Findings and recommendations

### 1. Decrease/Increase labels lack item context (medium; likely relevant to the report)
CartRow.swift:22 and :32 use generic labels, while only Remove (:41) names the item. With several rows, every row has identical "Decrease quantity"/"Increase quantity" buttons. In linear swipe order the preceding item name gives some context, but the Rotor "Buttons" list, Voice Control ("tap Increase quantity" is ambiguous, with duplicate names shown as numbers) and Switch Control do not. Change: include the item name, e.g. "Increase quantity of \(item.name)" (add the catalog keys), or make the quantity a single adjustable element (finding 2).

### 2. Quantity is split across three elements and duplicated as button value (low to medium)
Matches the reviewer note in CONTEXT.md. The quantity Text (CartRow.swift:25) is its own element, and both buttons also expose it as `accessibilityValue` (:23, :33). A VoiceOver user hears "Decrease quantity, 3, button", then "3", then "Increase quantity, 3, button". That is redundant, and a bare number as a button value reads like a state of the button rather than the quantity of the item, which could be what makes the controls hard to interpret. Preferred change: group the quantity control into one element, with `.accessibilityElement(children: .ignore)`, a label like "Quantity, \(item.name)", the value as the quantity, and `.accessibilityAdjustableAction` (increment/decrement), or hide the standalone Text from accessibility and drop the value from the buttons. A `Stepper` is another standard option. This is a design choice; the current setup is functional, not broken.

### 3. Decrement at quantity 1 is a silent no-op (medium)
CartModels.swift:27 ignores the decrement when quantity is 1, but the button (CartRow.swift:18) is never disabled and no feedback is given. VoiceOver users get no "dimmed" trait and no explanation; sighted users also see nothing happen. Change: `.disabled(item.quantity <= 1)` (the system adds the "dimmed" trait) or change the behavior to remove or confirm removal at 1; consider an announcement.

### 4. Destructive remove has no confirmation or undo (low to medium)
CartRow.swift:37 immediately removes the item (CartModels.swift:30), directly adjacent to the plus control. Mis-activations are more costly for VoiceOver, Switch Control and motor-impaired users. Also, when the row disappears VoiceOver focus is not managed (unverifiable which element receives focus). Consider a confirmation or undo and posting an announcement such as "Removed X". The "destructive" role does not add a VoiceOver cue by itself.

### 5. Multiple buttons inside one List row (functional risk; unverified)
CartRow.swift:18, 28, 37 are `Button`s with the default style inside a `List` row (CheckoutView.swift:14-18). In SwiftUI lists, multiple default-style buttons in a row are known to make the whole row act as the tap target, so a tap can trigger several buttons. Apply `.buttonStyle(.borderless)` or `.plain` to each. I could not verify this without running; it affects touch and possibly assistive-tech activation, so test it.

### 6. Dynamic Type, extreme sizes (low; unverified)
- Fixed 44pt frames on the icons (CartRow.swift:20,30,39) do not scale; the images are not `.resizable()` and not using `@ScaledMetric`, so at accessibility sizes the icons stay small next to large text. Consider `@ScaledMetric` for icon size.
- The name/price HStack (CartRow.swift:9-15) and Total row (CheckoutView.swift:22-28) have no fallback layout; at AX sizes a long name and price compete for width. `ViewThatFits` or switching to a vertical layout via `dynamicTypeSize.isAccessibilitySize` would be safer.
- The Total/Pay panel sits outside the List (CheckoutView.swift:21-35); at the largest sizes it consumes much of the screen, leaving little room for list rows. Check at AX5.

### 7. Minor
- Name and line price are separate elements (CartRow.swift:10,13); the context says this reads fine. Optionally combine into one element ("Name, $x").
- The Pay button and Total are separate; fine. The Pay button has no hint about total, optional.
- No `.accessibilityHint` on controls; not required given clear labels.
- `Image("ic_*")` is not marked decorative, but labels override so it has no effect.

## What I could not verify from source alone

- Actual VoiceOver output and focus order (nothing run; Accessibility Inspector has not been used per CONTEXT.md:11).
- The asset catalog (not included): the image's own accessibility label, intrinsic sizes (whether 44pt targets are actually met), template rendering, contrast in light/dark/Increase Contrast, and whether `ic_*` assets exist (a missing asset would render nothing but still be labeled).
- Whether the build the tester used matches this source, and any parent view or wrapper that could hide labels (CheckoutView is shown standalone here).
- The multi-button List tap behavior (finding 5) and layout at accessibility sizes (finding 6).
- Contrast of the borderedProminent button and of the destructive icon.
- Localization beyond English; the catalog has no translations, and accessibility strings would need them later.

## Suggested priority

1. Reproduce with VoiceOver/Accessibility Inspector to confirm what the tester heard (maybe the labels are fine and finding 1/2 is the real issue).
2. Disable decrement at 1 (finding 3); make quantity a single adjustable/combined element with item context (findings 1, 2).
3. Add `.buttonStyle(.borderless)` to row buttons (finding 5).
4. Removal confirmation/undo and announcement (finding 4).
5. Dynamic Type polish (finding 6).
