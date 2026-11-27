# Static localization audit

Scope: supplied `Screen.swift`, `Localizable.xcstrings`, and `context.txt`; English source with English, German, and French support. No inputs changed and no translations supplied. P2 = normal-priority correction/review; P3 = cleanup after verification.

## Actionable findings

| Priority | File/key evidence | Scoped action |
|---|---|---|
| P2 | `Localizable.xcstrings:31`, `%lld items` → `de/variations/plural/other/stringUnit/state` is `needs_review`. | Review this plural leaf before treating German coverage as complete. The existing value is present; this is an unresolved review state, not a missing translation. Preserve its `%lld` argument. |
| P2 | `Localizable.xcstrings:102`, `Download progress` → `de/substitutions/count/variations/plural/other/stringUnit/state` is `new`. | Complete review of the nested substitution. A top-level-only completeness check would miss it; do not promote its state automatically. |
| P2 | `Localizable.xcstrings:95–105`, `Download progress` German count substitution has only `other`, with `%lld Dateien`. | Supply and review a German singular branch if this count substitution is used. At count 1, the only supplied wording is plural. Confirm the call site and substitution wiring first: the German entry has no outer string unit referencing `count`, the source key has no visible argument, and the French value has no count. Whether the count is intended across locales and whether this compiles/renders cannot be established from these excerpts. |
| P3 | `Localizable.xcstrings:75`, `Deleted text` has `extractionState: stale`. | Verify references in the complete app and extraction output before removal. This hand-maintained catalog's marker is a cleanup lead, not proof the key is unused. |

## Linguistic review needing confirmation

`Localizable.xcstrings:63`, `%1$@ owes %2$lld`: German `%2$lld schuldet %1$@` appears to put the amount in the debtor position. Request fluent German review with the actual argument meanings. The positional placeholders themselves are compatible: argument 1 remains `@`, argument 2 remains `lld`; reordering is legal and is not evidence of a format-type defect. French preserves the same argument identities/types. This static check does not certify either translation's quality.

## Accepted behavior

- Missing French `Save` is the release's explicitly accepted English fallback (`context.txt`), not a defect.
- `BrandName` is intentionally nontranslatable (`shouldTranslate: false`).
- `Screen.swift` uses localizable SwiftUI literals for `Save` and `BrandName`; their presence in source is not a hardcoding finding.
- `Text(verbatim: serverStatus)` displays backend-localized text by the stated product contract; no client localization bypass defect is established.
- Absent explicit English translation entries can use source-key fallback. English plural behavior at the unseen `%lld items` call site remains unverified.

## Checks performed and pending

Ran the bundled read-only `catalog_inventory.py` for `en`, `de`, and `fr` successfully (six entries), then manually examined nested leaves, states, positional argument identities, and the supplied screen/context. Inventory exit 0 means parsing/inventory succeeded, not localization readiness.

Unavailable: Xcode build/extraction and catalog compilation; full call sites, target membership, bundle/table resolution, permission strings, or localized assets; runtime fallback and plural routing (including 0/1/2, large French counts, and negative counts if supported); rendered German/French expansion, accessibility sizes, or device layouts. Full plural-category behavior and linguistic accuracy need platform/fluent-review verification. RTL is outside the stated supported languages and was not tested. No date/currency formatting is shown. No rendered-layout defect or complete-app readiness claim can be made from these files.
