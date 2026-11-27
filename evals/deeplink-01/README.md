# Executable deep-link repair benchmark

This synthetic fixture isolates Foundation parsing and a synchronous navigation state machine. It does not exercise SwiftUI rendering, OS universal-link delivery, AASA hosting, authentication services, or device behavior.

## Contract and grading

The agent receives only [REQUEST.md](input/REQUEST.md), the broken [coordinator](input/RouteCoordinator.swift), and the selected skill when applicable. Requirements are written before runs; all 32 grader checks trace to that contract. Each run has its own input copy and may write its own tests. Agents are told not to read grading artifacts or sibling runs. Isolation is by task instruction, not a filesystem sandbox.

The parent compiles each final candidate with the same fixed [grader](grading/main.swift):

```sh
python3 evals/deeplink-01/grading/run.py evals/deeplink-01/runs/revised/RouteCoordinator.swift --output evals/deeplink-01/runs/revised/grade.json
```

The grader records compiler identity, source/harness hashes, compilation results, and every behavior result. Compilation failure is reported explicitly. Final agent reports are checked separately for evidence overclaims and unrelated changes.

The unmodified fixture passes 11/32. A separately written reference implementation passes 32/32, establishing that the stated contract is feasible under this harness. This is a benchmark validation, not evidence of skill effectiveness.

## Conditions

- No specialist skill: baseline capability of the available model/tools.
- ios-deeplink-doctor: the current collection's focused routing skill.
- swiftui-pro: comparator pinned in research/source-snapshot.json. Its documented navigation scope overlaps this task, but it is a broader SwiftUI skill.

Runs use independent agents with the inherited session model and no conversation history. Model internals and per-run token costs are not separately available. A single run per condition cannot establish a robust ranking. Preserve ties and failures; do not tune the grader after seeing candidates to manufacture wins.
