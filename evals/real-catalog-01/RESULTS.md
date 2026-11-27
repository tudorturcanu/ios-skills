# Real-app catalog validation

Source: [Ice Cubes at commit 98098b9](https://github.com/Dimillian/IceCubesApp/tree/98098b9c4b5928f89f338203193c2bf40ab7f38c). The checkout was read-only and unchanged; no app code or catalog is vendored here and no upstream report was sent. Source paths and SHA-256 hashes are in results.json.

The catalog contains 741 entries, 19 locale identifiers, and 2,219,826 bytes. German and French were selected because both are declared in the project. This is a static artifact inspection, not a build or runtime audit.

## Observed improvement

The retained original inventory produced 42 review items. The revised inventory produced 41. Exact comparison shows that only the missing-German item for the empty source key was removed; it is now recorded separately as an empty-source fallback. All other findings were unchanged: 31 missing-locale review items, five unresolved translation-state items, and five stale-extraction items.

These are review items, not 41 confirmed application defects. Product fallback policy, full call-site usage, compilation, and rendered UI behavior have not been established. The change reduces one known low-value review item without silently suppressing it from the evidence.

Five regression cases protect the boundary: empty-key fallback, meaningful source text under an empty key, explicit empty text under a semantic key, source plural variations, and a target empty string still needing review.

## Format checks grounded in call sites

Three flat format keys were selected after inspecting SwiftUI interpolation in the pinned source. All six German/French comparisons had compatible declared argument signatures. A follower-count key with nested substitutions was deliberately deferred to manual review. This does not establish linguistic correctness or runtime rendering.

Relevant source locations:

- [Status row accessibility](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/StatusKit/Sources/StatusKit/Row/StatusRowAccessibilityLabel.swift#L65)
- [Poll option accessibility](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/StatusKit/Sources/StatusKit/Poll/StatusPollView.swift#L126)
- [Account action](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/Account/Sources/Account/Detail/Components/AccountDetailToolbar.swift#L96)
- [Follower-count interpolation](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/Account/Sources/Account/AccountsList/AccountsListRow.swift#L70)

## Reproduce

Obtain the repository separately and check out the exact commit above. Then run:

```sh
python3 evals/real-catalog-01/reproduce.py --checkout /absolute/path/to/IceCubesApp
```

The runner verifies the commit and relevant file hashes, runs frozen tool versions, compares the observed outputs with retained results, and verifies that source hashes and checkout status did not change. It makes no network calls. This is a reproducible real-artifact tool evaluation, not a blinded agent comparison or proof of best-in-class performance.
