# Generation counts input and interpretation

`scripts/compare_generations.py` reads one JSON object and prints a classification per type. It only reads the file you pass.

## Input

- `schema_version`: `1`.
- `interaction`: the repeated interaction, such as "open and dismiss the photo picker".
- `samples`: one row per measurement, each with:
  - `cycle`: the nonnegative integer cycle number the sample follows.
  - `settled`: `true` when pending animations, callbacks, and image decoding had finished. Unsettled rows are listed as skipped and are not classified, so you can keep peaks in the record without mixing them into the comparison.
  - `counts`: surviving instance counts by type name, transcribed from Allocations generations or the memory graph.
  - `footprint_bytes` (optional): the footprint at the same point.

At least three settled cycles are required, at most one settled row per cycle. A type missing from any settled row is reported under `incomplete_types` and is not treated as zero.

## Patterns

| Pattern | Meaning | Next step |
| --- | --- | --- |
| `growing`, `steady: true` | Same number of survivors added every cycle | Trace incoming references in the memory graph to the owner that should release it |
| `growing`, `steady: false` | Growth that varies between cycles | Take an extra sample after the last cycle settles to rule out overlapping work, then test repeated and different inputs |
| `plateau` | Grew, then unchanged for the last two steps | Consistent with a bounded cache; confirm the bound with different inputs |
| `irregular` | Rises and falls | Samples are probably not taken at the same settled point |
| `shrinking` / `flat` | No growth | Not a growth candidate |

`growing` lists types fastest first. If footprint grows while no recorded type does, the output adds a `footprint_note`: look at non-object allocations such as decoded images and graphics buffers.

## Synthetic example

[synthetic-generations.json](synthetic-generations.json) holds invented numbers for checking interpretation, not device measurements. Expected result: `PickerModel` and `PickerCoordinator` grow by one per cycle, `ThumbnailCacheEntry` plateaus at 64, `PickerRowView` is flat, and the unsettled cycle 3 row is skipped.

## Limits

The helper classifies the counts it is given. It does not prove an ownership path, and a matching pattern is not a diagnosis. Record the build, device, data set, and Instruments template alongside the input so later runs compare like with like.
