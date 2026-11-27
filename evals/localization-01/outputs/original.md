# Static localization audit

Scope: `Screen.swift`, `Localizable.xcstrings`, and `context.txt` only. Source language is English; supported product languages are English, German, and French. No inputs were changed and no translations were written. Priorities below reflect catalog readiness; use of catalog keys outside the supplied screen is unverified.

## Actionable findings

- **P2 — German plural variant needs review.** `Localizable.xcstrings:29–33`, key `%lld items`, path `localizations.de.variations.plural.other.stringUnit.state`, is `needs_review`. The translated `one` variant does not establish completion of this entry. Have a qualified reviewer assess the existing plural variants, then update state only after review. The `%lld` argument type is preserved in both German and French variants.
- **P2 — German download substitution is incomplete.** `Localizable.xcstrings:91–110`, key `Download progress`, contains `substitutions.count` with argument 1 of type `lld`, but no enclosing German `stringUnit` message referencing that substitution. Its only plural variant (`other`, lines 100–104) is also `new`, and no `one` variant is supplied. Restore the enclosing message/substitution linkage and complete the count variants after confirming the intended message and call-site arguments. Validate compilation and rendered results for 0, 1, and multiple files. The excerpt cannot establish the exact runtime failure or fallback behavior.
- **P2 — Review German argument roles in the debt message.** `Localizable.xcstrings:58–64`, key `%1$@ owes %2$lld`, has German value `%2$lld schuldet %1$@`. Argument indexes and types are preserved, so this is not a placeholder compatibility error. However, the apparent subject/object roles change: the numeric argument precedes “schuldet,” while the named argument follows it. Ask a fluent reviewer to verify the intended debtor and amount against real call-site values and correct the wording if confirmed. Reordering arguments alone is valid and is not the finding.

## Evidence needed before changing other entries

- `Deleted text` has `extractionState: stale` (`Localizable.xcstrings:74–89`). Because the catalog is hand-maintained and only one screen is supplied, this is a cleanup candidate, not proof that the key is unused. Check all consumers and extraction output before deleting it.
- `%lld items` has no English plural variation (`Localizable.xcstrings:18–57`). If this key is used for a count of one, source-language fallback may expose the plural source wording. Its call site and supported count range are absent; verify before reporting a confirmed user-visible defect.
- `Download progress` has a French plain string and a German numeric substitution (`Localizable.xcstrings:91–117`). Confirm whether a count is required in every locale and how callers supply it before treating the French entry as missing a placeholder.

## Expected behavior, not defects

`Screen.swift:7` and `:9` use localizable SwiftUI literals. French `Save` fallback is explicitly accepted in `context.txt:1`. `BrandName` is intentionally nontranslatable (`Localizable.xcstrings:15–17`). `Text(verbatim: serverStatus)` (`Screen.swift:8`) displays text already localized by the backend according to the supplied context.

## Checks performed and pending

Performed static inspection of all three supplied files, including nested plural/substitution states, placeholder indexes/types, and call-site localization behavior. No app, build, or device checks were possible. Target/table/bundle membership, resource delivery, extraction freshness, English/German/French runtime fallback, plural selection across supported count ranges, and translation accuracy remain unverified. Render English, German, and French with long backend messages and the largest supported accessibility size to assess expansion and clipping. RTL is outside the declared language scope. No permission-string or locale-formatting call sites were supplied.
