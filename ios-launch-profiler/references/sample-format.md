# Measurement input and interpretation

The helper consumes an object with `schema_version: 1` and a nonempty `samples` array. Each row has:

- `sample_id`: a globally unique nonempty measurement identifier. If one launch yields two metrics, assign each metric its own ID and retain run provenance in the original artifact.
- `variant`: a build/experiment label, such as `before` or `after`.
- `duration_ms`: a positive finite numeric duration in milliseconds; convert known units explicitly.
- `conditions`: nonempty strings for `device`, `os`, `configuration`, `debugger`, `install_state`, `data_state`, `network`, `launch_kind`, `cache_state`, `interval`, and `instrumentation`.

Additional condition dimensions, such as thermal state, are included in grouping. Different labels create different cohorts. Preserve distinctions that matter: physical device vs simulator, process launch vs resume, first launch after migration vs steady state, debugger attached vs detached, and first frame vs ready-to-interact. Describe interval boundaries precisely in the source evidence. Do not rename unlike intervals merely to get a comparison.

Use `unknown` or `unspecified` where evidence is missing; either value suppresses comparison for that cohort. Do not fill missing measurements or infer zero from absent values. Keep raw data and cite its origin when converting Instruments exports, XCTest output, or manual records to this schema.

## Synthetic example

[synthetic-samples.json](synthetic-samples.json) contains invented numbers solely for validating interpretation. Run it with baseline `before` and candidate `after`. Expected medians:

| Interval | Before | After | Change |
| --- | --- | --- | --- |
| start-to-first-frame | 110 ms | 80 ms | -30 ms |
| start-to-ready | 210 ms | 310 ms | +100 ms |

First frame improves while readiness regresses. A blanket “launch got faster” conclusion would be misleading. These are not actual device measurements.

## Output limits

Negative change means a lower median duration. Spread, raw durations, and sample IDs remain available; outliers are never silently removed. Fewer than five observations in either variant raises an exploratory flag, not an automatic pass/fail threshold. Range overlap is descriptive and is not a significance test. Equal condition labels are necessary for grouping but do not establish that real conditions were controlled. Do not infer causality or a performance guarantee from this output.
