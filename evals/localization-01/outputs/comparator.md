# Localization review

Static review of the three supplied inputs only, using `swiftui-pro` and its localization reference. P2 means actionable follow-up; P3 means lower-priority verification. No input files or translations were changed.

## Localizable.xcstrings

**P2 — Finish review of nested German translation units (lines 29–33 and 95–104).**

- `%lld items` → `de.variations.plural.other.stringUnit.state` is `needs_review`.
- `Download progress` → `de.substitutions.count.variations.plural.other.stringUnit.state` is `new`.

These entries are not marked translation-complete, even though both contain text. Route the exact leaves for language review; change their states to `translated` only after acceptance. Before/after metadata: `"state": "needs_review"` or `"new"` → `"state": "translated"` after review. Neither state alone proves that users see a fallback or that compilation fails.

**P2 — Verify the German substitution's containing format (lines 91–110).**

`Download progress.localizations.de` contains only `substitutions.count`, with `argNum: 1` and `formatSpecifier: "lld"`. No German parent `stringUnit` or variation supplies a format referencing that substitution, and the source key itself has no argument. The excerpt therefore supplies a count-dependent fragment without showing how it becomes the displayed sentence. Confirm the intended call site and validate the entry with Xcode; provide the parent format and substitution reference if this is an active count-bearing message. Do not invent a translation or assume a demonstrated build failure. Before/after structure: substitution-only locale → validated containing format plus its referenced substitution.

**P3 — Add placeholder context and resolve semantic questions (lines 18–73).**

`%lld items` and `%1$@ owes %2$lld` lack translator comments. Document what each argument represents and whether the integer is a count or another quantity. The German owes value reverses argument order (`%2$lld schuldet %1$@`); its positional indexes and types still match the source, so this is not a placeholder-type mismatch. Ask a German reviewer to confirm the intended meaning. Before/after: no comment → a catalog `comment` describing verified argument roles.

## Accepted behavior and evidence limits

- `Screen.swift:7`: `Text("Save")` is localizable. Missing French for `Save` is an expressly accepted English fallback, not a defect.
- `Screen.swift:8`: `Text(verbatim: serverStatus)` correctly preserves backend-localized text under the supplied contract.
- `Screen.swift:9` and catalog lines 15–16: `BrandName` is intentionally nontranslatable.
- `Deleted text` is marked `stale` (lines 74–75), but these excerpts cannot establish that it is unused. Check complete call sites before removal, especially for a hand-maintained catalog.
- `%lld items` has no English plural variation; verify whether it is used with one item before requiring singular handling. The shown screen does not reference this key.

JSON parsing succeeded and recursive inspection included nested plural/substitution units. No project, toolchain settings, build output, running UI, or device was available. Catalog compilation, resource membership/bundle lookup, generated symbols, actual fallback selection, plural selection at runtime, backend language synchronization, layout expansion, and translation quality could not be verified.

Prioritize resolving the unfinished German units and the substitution structure, then add argument context and perform the remaining usage checks. No screen code change is supported by the supplied evidence.
