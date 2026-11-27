# Held-out comparison across all 13 skills: no measured advantage

Each skill was compared with a no-skill baseline on a held-out fixture pair: one codebase with a seeded defect and one corrected clean control (the first, `ios-offline-sync-review`, is in [offline-sync-02](../offline-sync-02/RESULTS.md); the other 12 are in the folders here). The same model family (`sonnet`) reviewed each fixture with and without the skill, read-only, from the same prompt (`PROMPT.txt`). 12 skills x 2 cases x 2 conditions = 48 reviews, plus the 4 from offline-sync-02.

## Results

| Skill | With skill | No skill | Script verdict |
| --- | --- | --- | --- |
| app-store-audit | 10 / 10 | 10 / 10 | no measured advantage |
| ios-accessibility-audit | 10 / 12 | 11 / 12 | no measured advantage |
| ios-crash-triage | 12 / 12 | 11 / 12 | improvement measured (one criterion) |
| ios-deeplink-doctor | 12 / 12 | 12 / 12 | no measured advantage |
| ios-launch-profiler | 12 / 12 | 12 / 12 | no measured advantage |
| ios-localization-audit | 11 / 12 | 11 / 12 | no measured advantage |
| ios-memory-growth | 12 / 12 | 11 / 12 | improvement measured (one criterion) |
| ios-permission-flow-tester | 11 / 11 | 11 / 11 | no measured advantage |
| iphone-duo-design | 12 / 13 | 12 / 13 | no measured advantage |
| storekit-entitlement-debugger | 11 / 12 | 11 / 12 | no measured advantage |
| swiftdata-migration-checker | 11 / 12 | 12 / 12 | no measured advantage |
| widget-data-consistency | 11 / 11 | 10 / 11 | improvement measured (one criterion) |
| ios-offline-sync-review (offline-sync-02) | 11 / 12 | 12 / 12 | no measured advantage |
| **Pooled (13 skills)** | **146 / 153** | **146 / 153** | |

The `read_only` criterion is counted and true everywhere (inputs and skill folders were diffed against the originals after the runs; none changed). False positives: 0 in all 52 reviews.

## How to read it

- **Defect detection is at ceiling for both conditions.** Both conditions found the seeded defect in every skill. The only defect-case miss in all 26 defect reviews was one `no_overclaim` criterion for the memory-growth baseline.
- **The remaining misses are one recurring style criterion.** 11 of the 14 failed criteria across both conditions and all 13 skills are the clean-case `no_unfounded_rewrite` (suggestions not labeled optional or low priority), including in both conditions for several skills. Whether the skill or baseline wins a given row usually comes down to that one judgment call.
- **The three "improvement" rows are one criterion each.** A one-criterion difference from a single run is within noise: in offline-sync-02 two grading rounds flipped a single criterion on the same report. The script's rule (strictly more criteria passed, no more false positives) is deliberately simple and does not model noise, so treat those rows as ties until repeated.

## What this does and does not show

- It shows that on well-specified, source-only review tasks, a capable model without the skill already finds these defects and avoids false alarms on clean code, and the skills did not measurably change that. This repeats the earlier deeplink, localization and offline-sync results.
- It does not show the skills are useless. The fixtures are small (3 to 6 files), source-only, and test review accuracy, not the evidence-gathering helpers (AASA inspector, catalog inventory, migration probe, ips inventory), which need real artifacts and are where the research notes expect value.
- Cost, latency and token use were not compared.

## Method and limits

- **Fixtures** were written by separate agents that were told not to read the skills, so they are not tailored to skill wording. Rubrics were written before any review ran. The fixtures and rubrics were authored by the same model family as the reviewers and graders, which may favour agreement.
- **One run per condition**, one model, no repeats: no statistical claim.
- **Grading** was done by a separate agent per skill, strict per-criterion with quoted evidence, on reports with skill mentions scrubbed and relabeled in shuffled order (`blind-inputs/`, `mapping.json`). Blindness is partial: skill-guided reports often have recognizably different structure (state tables, "ask the backend" sections). The first offline-sync-02 round was not blind and is superseded.
- **No previous-version baseline.** Each skill has a single commit, so there is no earlier version to freeze, which the [protocol](../PROTOCOL.md) otherwise asks for.
- **Reviewers could read the skill's whole folder** (SKILL.md and references) but not run its scripts; helpers were therefore not exercised.
- Reproduce a grading: `python3 scripts/aggregate_heldout.py <work dir>` maps `blind/grades.json` back to conditions via `mapping.json` and runs `scripts/compare_conditions.py`.
