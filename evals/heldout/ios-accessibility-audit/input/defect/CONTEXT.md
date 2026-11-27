# Checkout cart screen

Our iOS 17 app (SwiftUI) has a cart screen shown before payment. A tester who uses VoiceOver
reported that on the cart screen they cannot tell what the controls on each item row do and
had to guess; the rest of the screen (item names, prices, the Pay button) reads fine.

Notes:
- The icons `ic_minus`, `ic_plus` and `ic_remove` are custom artwork in our asset catalog
  (not SF Symbols); the catalog is not included here.
- Strings live in Localizable.xcstrings (English only for now).
- Nobody has run the Accessibility Inspector on this screen yet.
