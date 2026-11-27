# Baseline-versus-revised evaluation protocol

Use this for any claim that a skill revision helps. Packaging checks and tool unit tests do not count.

1. **Freeze** the baseline (no skill, and the previous skill version) by commit hash before editing the revision.
2. **Cases per skill**: at least three defect fixtures from `tests/scenarios.md`, one clean control (expected: no confirmed defect, unverified areas listed), and two near-miss routing prompts.
3. **Held-out**: write expected outcomes before the first run; do not tune the skill on the held-out cases.
4. **Same conditions**: one model, one tool set, one fixture revision, identical prompts. Record all three.
5. **Grade outcomes** per criterion: correct diagnosis, working fix where requested, preserved behavior, false positives, and honest reporting of missing evidence. Grade blind when a separate grader is available; otherwise say the grading was unblinded.
6. **Report** every run, including failed and inconclusive ones, with cost and latency kept separate from correctness.
7. **Claim** (checked by `scripts/compare_conditions.py`) an improvement only if the revision beats both baselines on held-out cases. Otherwise record "no measured advantage".
