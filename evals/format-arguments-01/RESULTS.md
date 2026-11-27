# Format argument checker verification

A fresh `npx skills` copy installation found all ten skills and preserved their bundled files. The installed checker was run against the retained catalog with five explicitly selected, known format-string keys.

| Case | Observed result |
| --- | --- |
| Object argument changed to integer | Reports argument-type-change |
| Positional argument reordering | Compatible declared signatures |
| Repeated positional argument | Compatible declared signatures |
| Escaped percent sign | Compatible declared signatures |
| Plural variation | Manual review; no compatibility claim |

An ordinary text entry containing a percent sign was deliberately not selected. The helper requires call-site knowledge and is not a scan of every percent character.

The 19 focused Python tests cover the restricted grammar, type mapping, safe deferrals, input validation, and read-only CLI behavior. Independent review found one low-priority malformed-input error: deeply nested JSON escaped the structured error path. That was fixed and tested across all five JSON diagnostic programs. The full collection suite now has 75 passing tests.

Eight valid formatting examples were also executed through Foundation with Swift 6 language mode and warnings as errors. Their source hash and actual outputs are retained in foundation-results.json. One initial test assumed zero padding from a locale-aware floating-point format; actual output used spaces. The final width test explicitly checks space padding instead. The checker compares argument signatures, not presentation behavior, and its logic does not assert padding equivalence.

These checks are not a comparative agent benchmark, do not prove arbitrary format syntax valid, and do not establish full catalog or translation correctness. Unsupported syntax, plural/substitution structures, actual call-site arguments, and target-platform rendering still require review.
