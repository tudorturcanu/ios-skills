# Localization comparison: no measured correctness advantage

Three independent agents reviewed identical input using the original skill, revised skill, or SwiftUI Pro at the commit pinned in the research snapshot. All three reports satisfied the nine prewritten criteria. The parent agent graded full reports manually; grading was not blinded.

| Condition | Criteria satisfied | Inspection approach |
| --- | --- | --- |
| Original | 9 / 9 | Direct source and catalog reading |
| Revised | 9 / 9 | Bundled catalog inventory plus manual review |
| SwiftUI Pro comparator | 9 / 9 | Recursive ad hoc JSON inspection plus manual review |

All runs found nested German translation-state issues, honored accepted fallback and backend-localized text, avoided placeholder-reordering false positives, and acknowledged unavailable runtime evidence. They also noticed the fixture's incomplete containing format for a count substitution. Original inputs and baseline/revised skill hashes matched the pre-run manifest afterward.

This case shows that the revised skill can use the helper without losing contextual judgment. It does not show improved correctness, speed, or token cost. Per-agent timing/token measurements were unavailable; no efficiency claim is made. More varied and held-out cases are required.

See [rubric](rubric.json), [graded evidence](results.json), and [outputs](outputs/).
