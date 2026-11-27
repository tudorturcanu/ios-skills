# Offline-sync review: no measured advantage over a no-skill baseline (skill scored one criterion lower)

Held-out comparison of the `ios-offline-sync-review` skill against a no-skill baseline on two new fixtures: a defect case (order queue that retries a non-idempotent POST; the fake server commits then times out) and a clean control (same queue with a persisted operation ID sent as an idempotency key, and a documented server contract). The [rubric](rubric.json) was written before any run. Four read-only reviews ran under identical conditions (same model family, `sonnet`; same prompt except the skill instruction; one run each) and the outputs are in [outputs](outputs/). Fixture directories were verified unchanged after the runs.

| Condition | Defect case | Clean control | False positives |
| --- | --- | --- | --- |
| No skill | 7 / 7 | 5 / 5 | 0 |
| With skill | 7 / 7 | 4 / 5 | 0 |

The table is the second, blind grading round (below). The first round was not blind and scored both conditions 12 / 12 on the six non-read-only criteria per case; it is superseded, not hidden.

[`scripts/compare_conditions.py`](../../scripts/compare_conditions.py) over the [skill](grading-skill.json) and [baseline](grading-baseline.json) gradings reports **no measured advantage** (the skill is one criterion behind).

## What differed qualitatively

Both defect reports found the ambiguous acknowledgment, the missing operation identity, the need for a server contract, and the test gap. The skill-guided report added a durable state table, an explicit "committed but not removed" restart window, and a "do not auto-resend an ambiguous order" mitigation; the baseline added concurrency and atomic-write notes. Both clean-control reports correctly declined to claim a duplicate defect, and both flagged the 7-day idempotency window and the unverified real transport. These differences are not in the rubric and were not scored.

## Second grading round (blind)

Skill mentions were scrubbed from all four reports, they were relabeled A to D in a different order, and a fresh grader scored them without being told the conditions ([inputs](blind-grading-inputs/)). One decision changed: the skill-guided clean-control report lost `no_unfounded_rewrite` because it proposed a five-item change list (error classification, retry caps, failed state, account scoping, atomic persistence) without labeling the items optional, even though it correctly found no duplicate defect. The first grader had counted the same report as passing. Single-criterion grader disagreement of this kind shows the rubric item is judgment-dependent, so this difference should not be read as a skill regression either.

## Limits

- Single run per condition, one model, two cases written by the skill's author: no statistical claim and no generalization.
- Blindness is partial: scrubbing removed explicit skill mentions, but the skill-guided reports have a recognizably different structure (state tables, ask-the-backend sections), and the first grader round was not blind.
- Only a no-skill baseline was run. The protocol also requires the previous skill version; the skill has a single commit in history, so no earlier version exists to freeze.
- Source review only: no builds, no runtime, no backend.
- Consistent with [the earlier deeplink and localization results](../../research/competitive-review.md): for explicit, well-specified review tasks a capable model without the skill already performs at ceiling. A harder or more ambiguous fixture would be needed to separate the conditions.
