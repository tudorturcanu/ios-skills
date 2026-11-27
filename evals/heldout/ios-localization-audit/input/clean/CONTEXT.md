# Context

Shop app "Kiosk", String Catalog `Localizable.xcstrings`, source language English, shipped locales: en, de, ru.

Support ticket from the Russian App Store listing: customers say the cart header reads wrongly for some quantities
(e.g. with 2 or 5 items the wording looks ungrammatical), while English and German look fine. QA also asked whether the
reordered placeholders in the shipping line are a problem.

Team notes: all user-facing strings use catalog keys via SwiftUI `Text`/`Button` (LocalizedStringKey). Plural strings are
authored as catalog plural variations. Russian CLDR plural categories are one, few, many, other. German and English use one, other.

The Russian entry for the cart count was reviewed against CLDR categories in the last translation round and all four categories are present.
