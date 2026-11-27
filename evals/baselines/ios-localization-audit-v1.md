---
name: ios-localization-audit
description: "Audit or fix iOS localization extraction, String Catalog coverage, pluralization, formatting, RTL behavior, and text expansion. Use for localization defects or readiness checks, not unsolicited translation of an entire app."
---

# iOS Localization Audit

Separate text extraction, translation completeness, linguistic quality, and rendered layout; passing one does not prove the others.

## Inventory

Determine source language, supported locales, target membership, String Catalog tables, legacy strings/stringsdict resources, localized assets, and app/extension bundles. Build with the relevant configuration when available to refresh extraction; inspect the resulting diff before accepting removed or stale keys. SwiftUI string literals in localizable APIs are not automatically hardcoded defects. Trace dynamic String values and verbatim APIs to determine whether localization is actually bypassed.

## Inspect content

Find concatenated sentences, manual plural branches, locale-insensitive dates/numbers/currencies, and ambiguous translator comments. Preserve interpolation types and positional arguments; compare placeholders semantically, allowing reordering. Evaluate plural categories for the target language, not just English singular/other. Inspect nested catalog variations and substitutions instead of only top-level stringUnit values.

Respect entries intentionally marked nontranslatable, source-language fallback, and explicit locale fallback policy. Do not mark draft machine translations reviewed or translated merely to satisfy a completion metric. Use the requested terminology and retain product names where appropriate.

Inspect localization at the bundle and table used by call sites, including packages and extensions. Ensure InfoPlist strings and permission explanations reach the correct target. Treat missing entries, untranslated entries, and stale extraction state as different findings.

## Verify rendering

Select representative supported locales: expansion-prone text, RTL if supported or requested, non-Latin scripts, and differing number/date conventions. Test largest supported accessibility sizes, buttons, tab labels, alerts, input, and errors. Use semantic leading/trailing layout while checking directional icons and content that must not mirror, such as media or identifiers. Do not reverse strings manually to implement RTL.

Run plural boundaries, zero, negative values where relevant, long names, and mixed-direction content. Confirm currency formatting reflects the intended currency rather than silently changing monetary meaning with locale. Separate translation accuracy requiring a fluent reviewer from technical checks.

Return file/key-specific findings, scoped fixes, and locale/device checks performed or pending. Avoid replacing catalogs wholesale and preserve comments and unrelated translations.

## Reference

Consult [Apple String Catalog guidance](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) for extraction, variants, and current editor behavior.
