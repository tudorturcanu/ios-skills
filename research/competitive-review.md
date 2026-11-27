# Competitive review — 2026-11-04

## Selection and limits

The skills.sh directory showed SwiftUI Pro at approximately 36.8K installs and SwiftUI Expert at 35.8K. These are relevant, widely installed comparators, not a proven exhaustive ranking of iOS skill quality. The general leaderboard also includes Vercel React Best Practices and Anthropic Frontend Design. Counts are a discovery signal; they do not measure correctness or causal benefit.

Sources: [SwiftUI Pro listing](https://www.skills.sh/twostraws/swiftui-agent-skill/swiftui-pro), [SwiftUI Expert listing](https://www.skills.sh/avdlee/swiftui-agent-skill/swiftui-expert-skill), [leaderboard](https://www.skills.sh/). Repository commits inspected are pinned in [source-snapshot.json](source-snapshot.json). No competitor code or prose is vendored into our skills.

## What the inspected implementations do

| Comparator | Observed design | Consequence for our collection |
| --- | --- | --- |
| [SwiftUI Pro](https://github.com/twostraws/swiftui-agent-skill) | Topic references, explicit review sequence, file/line findings, before/after examples, and partial-review routing. | Add actionable examples where an agent decision is ambiguous, and require evidence local to each finding. Do not copy target-version assumptions into unrelated projects. |
| [SwiftUI Expert](https://github.com/avdlee/swiftui-agent-skill) | Task/topic routing plus bundled Instruments capture and analysis scripts; source changes can be grounded in trace evidence. | Move repeatable inspection into portable tools, document what they prove, and keep manual interpretation where the tool cannot be authoritative. |
| [Vercel React Best Practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices) | Prioritized rule categories and individual rules with rationale and incorrect/correct examples. | Prioritize user impact rather than reporting every pattern equally; use small examples for state-transition failures. |
| [Anthropic Frontend Design](https://github.com/anthropics/skills/tree/main/skills/frontend-design) | Explicit quality direction, a plan/build/critique process, and concrete failure patterns. | Define what success looks like for a diagnostic task and critique claims against evidence before delivery. |
| [Anthropic Skill Creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) | Baseline comparisons, realistic task cases, assertion grading, and iteration from observed behavior. | Keep tool tests separate from agent evaluations; preserve baseline artifacts and evaluate task outcomes rather than prose similarity. |

This is source inspection of prescribed behavior, not an execution benchmark of those agents. No superiority claim follows from it.

## Current improvement

Three independent, standard-library, read-only helpers now provide structured evidence for catalog states, AASA identity alignment, and JSON crash-report structure. Their tests include defects, valid edge cases, malformed inputs, CLI behavior, and unchanged input files. The skills route to them only when the relevant artifacts exist. Helpers report limitations and do not label an entire app healthy.

## Remaining quality gates

1. Run realistic task fixtures against frozen baseline skills and revised skills under the same model and tool conditions. Include multiple cases per skill, clean controls, and near-miss routing prompts.
2. Grade concrete outcomes: correct diagnosis, successful fix where requested, preserved behavior, false positives, and accurate reporting of unavailable evidence. Keep cost/latency separate from correctness.
3. Compare against relevant competitor skills only on their overlapping scope. A general SwiftUI skill should not be marked down for not specializing in server-backed entitlement recovery.
4. Repeat on held-out cases before claiming improvement. Record unsuccessful and inconclusive runs as well as wins. Popularity and a small synthetic test suite cannot establish “best.”

The full thirteen-skill collection (ten at the time of the earlier evaluations below) is still an early implementation. The initial structural validation was necessary but insufficient; the first localization agent comparison is now complete and found no correctness advantage. See [results](../evals/localization-01/RESULTS.md); broader comparisons remain outstanding.

## Executable follow-up

The [routing repair benchmark](../evals/deeplink-01/RESULTS.md) compiled final candidates against 32 fixed behavior checks. All three conditions passed, including a no-skill control. This suggests our next improvements and evaluations should emphasize collecting and interpreting domain evidence, where reusable tools can add concrete value, rather than adding instructions for an already explicit algorithmic contract. This is a design inference from a small test, not a general conclusion about skill utility.

## Migration tooling follow-up

The SwiftData skill now includes an executable synthetic probe, verified from an installed copy. Six migration paths check actual disk persistence, exact source/destination schema versions, and semantic values after fresh-process reopening. A successful-but-corrupting rename serves as a negative control. See [retained results](../evals/migration-probe-01/RESULTS.md).

This adds a concrete reusable capability beyond prose guidance. It has not been compared with competing migration skills and does not establish overall superiority. Historical app fixtures and target-iOS validation remain separate requirements.

## Localization argument tooling

The localization skill now has a separate selected-key argument checker alongside its translation-state inventory. It distinguishes declared type changes from valid positional reordering and repetition, while deferring unsupported syntax and plural/substitution structures. Independent review identified and led to a fix for deeply nested JSON error handling. [Retained evidence](../evals/format-arguments-01/RESULTS.md) includes focused tool tests and actual Foundation formatting examples. This provides a reusable inspection capability; no new comparative agent advantage is claimed.

## Real-app follow-up

A read-only inspection of a pinned Ice Cubes checkout exercised both localization tools on a 2.2 MB real catalog. It exposed an empty-source fallback review item that did not need translation work. The revised inventory records that fallback separately, with five targeted regression cases protecting meaningful text and plural structures. [Reproduction and evidence](../evals/real-catalog-01/RESULTS.md) preserve the source commit/file hashes without vendoring app code. This is a small observed tooling improvement on a real artifact, not an overall superiority claim.

## Specialized WidgetKit comparison

Two independent source reviews of the same pinned app used our focused widget skill and `dpearson2699/swift-ios-skills`' WidgetKit skill at commit `8d90fd121a263355a4fb44fd082af1416a5c1c2a`. Both met eight criteria under unblinded parent grading; the separate blind grader failed with a workspace-credit error. Each report found an additional valid issue the other omitted. [Full results](../evals/widget-review-01/RESULTS.md) preserve the reports, frozen instructions, hashes, grading limits, and correction caveats.

The source review supports adding guidance about optional asset failures, configured identity, and full logout paths. It also exposed a read helper with write side effects, illustrating why a proposed fresh-read fix must inspect the actual helper. These changes improve the specificity of the instructions, but there is no measured behavioral advantage for the revised version yet.

## Posting recovery follow-up

A parent-led investigation of the same pinned app found that a failed thread reply collapses partial success to nil, while recovery inserts only root text. A [five-case executable probe](../evals/offline-recovery-01/RESULTS.md) runs two exact source methods with test doubles and confirms both the successful reply chain and incomplete failure recovery. It does not execute network effects, persistence, or the full app. The offline-sync skill now covers per-step acknowledgment, recoverable payload completeness, and server deduplication expiry. The findings are concrete method-level evidence; incremental agent value remains unmeasured.

## Photo permission follow-up

The [photo investigation](../evals/photo-permissions-01/RESULTS.md) adds actual simulator API and picker-presentation evidence, while preserving unsuccessful full-library grant controls. Three newly created simulators were deleted after use. This led to permission guidance that distinguishes picker/library/save operations, cached authorization from current capability, and successful CLI assignment from observed framework status. The source findings concern Ice Cubes; the runtime observations concern a separate synthetic app. Neither establishes comparative agent superiority, and the full simulator assertion set did not pass.

## StoreKit lifecycle follow-up

A [local StoreKit investigation](../evals/storekit-lifecycle-01/RESULTS.md) exposed a flaw in the first probe: immediate empty snapshots allowed vacuous refund and finish checks. Requiring observed prior access/unfinished transactions and bounded state observation produced actual purchase, refund, and consumable-completion evidence on iOS 27.0. A grow-only reducer retained revoked access, as intended for the negative control.

The final probe recorded 12 of 13 booleans true; verification-error injection into a cached entitlement did not produce an unverified result, so neither failure handling nor recovery was exercised. XCTest failed and its wrapper timed out. Nine attempts, including setup failures, remain frozen and indexed. The skill gained explicit guidance on transition preconditions and failure-injection evidence; the investigation does not establish incremental agent value or a fully passing StoreKit test suite.

A tenth attempt used an app-facing fresh purchase under verification injection, with recovery constrained to the same transaction ID. It stalled without a completed probe result; the new checks remain unexercised. This exposed a diagnostic gap in the probe itself: it saved observations only at completion. The current implementation checkpoints prior observations at each phase and preserves partial evidence separately. Swift type checking passed; runtime interruption behavior for this checkpoint revision remains unverified. Two evidence regressions reject recovery without an observed failure or with a different transaction ID.

## Held-out offline-sync comparison

The first run of the [evaluation protocol](../evals/PROTOCOL.md) compared the offline-sync skill with a no-skill baseline on a held-out defect fixture and a clean control. Both conditions found every real defect with no false positives; the blind grading round scored the baseline 12/12 and the skill 11/12 (one judgment-dependent criterion), so the result is **no measured advantage**; see [results](../evals/offline-sync-02/RESULTS.md) for limits (one run per condition, not fully blind, previous skill version not compared). This repeats the pattern from the deeplink and localization comparisons and points toward harder fixtures and evidence-collecting tools as the place a skill can add value.

## Held-out comparison of all 13 skills

The [protocol](../evals/PROTOCOL.md) was applied to every skill: a seeded-defect fixture and a clean control each, reviewed with and without the skill (52 reviews), graded per criterion on scrubbed, relabeled reports. Pooled score: 146/153 with the skill and 146/153 without; defect detection was at ceiling for both, and three single-criterion differences in the skill's favour are within noise. See [results](../evals/heldout/RESULTS.md). The evidence-gathering helpers were not exercised by these source-review tasks, so this says nothing yet about their value.
