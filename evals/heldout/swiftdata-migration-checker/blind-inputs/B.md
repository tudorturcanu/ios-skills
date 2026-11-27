# Trailhead SwiftData migration review (V1 -> V2), read-only

Nothing was built or run. All claims are from source. Paths are relative to project/.

## Bottom line
I found no defect in the shown source that explains "all hikes show 0.0 km after updating from 1.3". The migration design is a recognised pattern: the old column is kept as an optional property via originalName, and a custom stage backfills the renamed field. On paper it preserves distance. The symptom therefore most likely comes from something this source cannot show, such as what the beta users' stores actually contained, or which build and schema last opened them. I did not invent a bug. Details, caveats and next experiments follow.

## Schema-difference table
| Item | V1 (Models/SchemaV1.swift) | V2 (Models/SchemaV2.swift) | Notes |
|---|---|---|---|
| Entity | Hike (L10) | Hike (L10) | Same entity name |
| name, date | String, Date (L11-12) | same (L11-12) | Unchanged |
| distance | `distance: Double` (L13) | none under that name | Column mapped to `legacyDistance` |
| legacyDistance | n/a | `@Attribute(originalName: "distance") var legacyDistance: Double?` (L19-20) | Carries V1 values; required to optional |
| distanceKm | n/a | `Double = 0` (L13) | New property with default 0, so it is 0 for every migrated row until backfilled |
| notes | `String = ""` (L14) | same (L14) | Unchanged |
| isFavorite | n/a | `Bool = false` (L15) | Additive, lightweight-safe |
| Version id | 1.0.0 (L6) | 2.0.0 (L6) | Distinct |

The change is a rename done as "originalName on a different new property, then copy". It is not a plain `originalName: "distance"` on `distanceKm`. That is why a data-copy stage is needed, and why a missed or failed copy gives exactly 0.0 km.

## Findings

### 1. Wiring and stage logic look correct (no issue)
- Plan lists [SchemaV1, SchemaV2] in order and one custom stage v1ToV2 (HikeMigrationPlan.swift L4-10, L14-17).
- didMigrate fetches only `SchemaV2.Hike` (L19), which is valid because after the schema change the V2 types are the ones available. It copies `legacyDistance` to `distanceKm` when non-nil and saves (L20-25). It does not need both V1 and V2 types at once.
- The app container uses `Schema(versionedSchema: SchemaV2.self)` with `migrationPlan: HikeMigrationPlan.self` (App/TrailheadApp.swift L12-17). It uses the default store location, not a custom URL. I saw no extension or other container in the supplied files.
- V1 is documented as shipped and unedited (SchemaV1.swift L4).

### 2. Tests do not prove the fix for real shipped stores (verification gap, real weakness)
Tests/HikeMigrationTests.swift is green but weak evidence:
- One record only (L24-26). A silent reset on some rows but not others, or a swapped value, would not be caught. Seed at least two hikes with different non-default distances, plus notes, and assert by name.
- It never asserts `legacyDistance`, so it does not check the intended end state of the old column (L36-41).
- No close and reopen after migration (L32-41). The guidance requires reopening to catch unsaved or non-persisted changes. Since the migration depends on an explicit `context.save()` in didMigrate, a reopen assertion matters here.
- The V1 fixture is created in the same process, using the current compiled V1 class, not a store produced by the real 1.3 app. That does not show the shipped store's metadata, hash or version are what this plan expects.
- No edge cases: a hike with distance 0, empty store, large store.
- The fresh-install case (the QA scenario in CONTEXT.md) is not a migration test.
Change: add a reopen step, multiple records with distinct values, and ideally a fixture store produced by a 1.3 build, copied as a bundle with sidecars (-wal, -shm).

### 3. Possible causes that I cannot confirm or rule out from source
Fresh installs work and names, dates and notes survive, which matches "distance column not backfilled" or "never carried". Candidates to test, in rough order:
1. Stage never ran for affected stores. If those beta users' stores were already opened by a pre-release 1.4 build that had a different or earlier V2 (for example no migration plan, or `distanceKm` added without `legacyDistance`), the store's version would already be V2 and didMigrate would not run again, leaving 0. SchemaV2 is not marked as final. Check the git history and beta builds for earlier V2 shapes, and the version number recorded in the affected stores.
2. Store was reconciled by an inferred (automatic) migration without the plan, for instance a container created elsewhere (widget, extension, previous launch path) without `migrationPlan`. I saw no such file but the project listing is partial per CONTEXT.md.
3. Behaviour of originalName combined with a custom stage in the SDK used. The guidance says to check current SDK documentation rather than assume. I cannot confirm from source that `legacyDistance` actually receives the V1 values at didMigrate time on every supported OS version. A direct inspection of an affected store's SQLite columns (ZDISTANCE, ZLEGACYDISTANCE, ZDISTANCEKM) would settle this. Run it on copies only.
4. Any `legacyDistance == nil` rows, for example if a beta build wrote rows with only `distanceKm`. The `if let` silently skips them (HikeMigrationPlan.swift L21) so they remain at the default 0 with no signal.

### 4. Design smell, not a bug
`legacyDistance` stays in the schema permanently (SchemaV2.swift L17-20) and any code reading it is ambiguous with `distanceKm`. Plan a V3 cleanup after 1.4 data is confirmed healthy. Also, `didMigrate` swallows nil silently; consider logging a count of rows copied versus skipped.

## What I could not verify from source alone
- What the 1.3 production store actually contains (fixture provenance, SDK, OS).
- Whether the stage ran for affected users, and which build last opened their stores.
- Whether any app extension, widget or CloudKit configuration exists. None appears in the provided files.
- Runtime behaviour of the migration on the supported OS versions.
- The view code (HikeListView, yearly total) was not provided, so I cannot check whether it reads `distanceKm` or something else.

## Recommended next steps
1. Obtain a copy (not the original) of an affected user's store, including sidecars, and inspect the column values and recorded schema version.
2. Build a fixture with the real 1.3 build; open it with the current plan in a test; assert two or more distinct non-default distances; close and reopen and assert again.
3. Audit beta build history for any earlier V2 definitions or containers created without the migration plan.
4. For users already stuck at 0, plan a repair: if the old column data still exists (legacyDistance non-nil), a one-time backfill at launch can copy it. If it is gone, recovery needs backups. Do not delete or reset stores.
