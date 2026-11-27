---
name: ios-launch-profiler
description: "Measure and diagnose iOS application startup using launch traces, metrics, and matching source, then verify targeted improvements. Use for runtime launch latency, not Xcode build or compilation duration."
---

# iOS Launch Profiler

Optimize the measured path to usable UI, including any work shifted beyond the first frame.

## Establish a baseline

Record hardware, OS, build configuration, debugger attachment, install state, app data, network conditions, and what launch interval the tool measures. Separate process launches, resumes, and first launch after installation or migration. Do not label every process launch cold without defining cache conditions. Use release-like builds on representative hardware for user-facing performance claims.

Collect repeated comparable samples using available Instruments, XCTest launch metrics, signposts, or supplied traces. Record individual samples and a summary with spread, not just the fastest run. Choose sample count appropriate to noise and cost. Never invent timings when tooling or a device is unavailable; source inspection then produces hypotheses only.

When the first screen draws before its primary action becomes usable, capture both endpoints from the same launch where possible. Use a milestone tied to the actual action, such as the saved list finishing its load and accepting selection. Record the measurement API and initializer or signpost boundary. Keep Organizer first-draw metrics separate from app-defined readiness. [Apple’s launch measurement guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)

## Find the critical path

Separate pre-main/image loading, application initialization, scene setup, first rendering, and readiness for interaction. Identify whether the blank screen is the system launch screen, a rendered loading state, or a launch failure before selecting a performance experiment. Inspect synchronous disk access, decoding, database opening/migration, dependency construction, SDK initialization, and main-thread waits only where evidence puts them on the path. Attribute time using trace intervals and stacks; source length is not a timing measurement.

Distinguish CPU work from waiting, lock contention, and I/O. Check dependencies before moving work into tasks: UI isolation, order, error recovery, cancellation, and data readiness must remain correct. Avoid merely moving a blocking operation to the moment of the user's first tap. Defer genuinely optional work and retain visible loading states when necessary.

When analyzing a saved trace, record the Xcode/Instruments version and confirm the trace contains the target process, time range, and measurements before judging an empty result. Xcode 27.3 beta adds richer `xctrace` exports and hang triage. Check the installed tool’s help for those commands. Use the selected interval in Instruments when the installed CLI lacks those exports. [Xcode release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_3-release-notes)

## Validate changes

Apply one meaningful change at a time when feasible and repeat the same measurement conditions. Compare distributions and report uncertainty if noise overlaps the apparent gain. Verify first interaction, deep-link launch, offline startup, and data migration paths affected by the fix. Keep instrumentation and cleanup scoped to the task.

Return baseline versus changed samples, measured interval definitions, traced bottlenecks, changes, and regressions checked. If limited to supplied traces, clearly distinguish analyzed historical evidence from a new benchmark.

## Supplied measurement analysis

When launch samples are supplied, use [compare_launch_samples.py](scripts/compare_launch_samples.py) to summarize them under matching conditions. Read [sample format and interpretation](references/sample-format.md) for conversion rules and a synthetic example. Resolve the script path from this installed skill directory:

```sh
python3 /absolute/path/to/ios-launch-profiler/scripts/compare_launch_samples.py samples.json --baseline before --candidate after
```

The helper reads one JSON file, uses only Python 3 standard-library modules, and makes no network calls or writes. Exit 0 means analysis completed, including when conditions prevent comparison; exit 2 means invalid/unrepresentable input. It does not record a trace or benchmark an app. Preserve original measurement provenance and represent missing condition values as `unknown`, never guessed equivalence.

## Diagnostic cases

Read [diagnostic cases](references/diagnostic-cases.md) when choosing the next experiment or building a regression test. Use the cases that match the observed failure.

## Reference

Read [Apple launch-time guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time) for the current measurement workflow and launch phases.
