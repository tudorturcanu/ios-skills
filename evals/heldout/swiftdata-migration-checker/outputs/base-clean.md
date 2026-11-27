# Trailhead SwiftData migration review (base-clean)

## Verdict
I found no defect in the five provided files that explains "0.0 km" after updating from 1.3 to 1.4. The migration is correct as written, and I am not going to invent a bug. The root cause most likely sits outside these files (see "Could not verify").

## Evidence that the migration is sound
- Models/SchemaV1.swift:13 stores `distance: Double` (km). Models/SchemaV2.swift:13 adds `distanceKm: Double = 0`, and :19-20 adds `@Attribute(originalName: "distance") var legacyDistance: Double?`. SwiftData therefore maps the old `distance` column onto `legacyDistance`, so the V1 value is preserved in the store through the schema change.
- Models/HikeMigrationPlan.swift:5 lists both schemas in order, and :9 lists the single custom stage. The stage is V1 to V2 (:15-16). Its `didMigrate` (:18-26) fetches `SchemaV2.Hike`, copies `legacyDistance` into `distanceKm` when non-nil, and saves. That is the expected pattern for a rename that goes through a custom stage.
- App/TrailheadApp.swift:12-17 builds the container from `SchemaV2` and passes `migrationPlan: HikeMigrationPlan.self`. The plan is wired into the production container.
- Tests/HikeMigrationTests.swift:19-42 builds a real on-disk V1 store and reopens it with V2 plus the plan. It asserts `distanceKm == 12.5`. This covers the exact upgrade path, so the green test is consistent with the code. It is not a vacuous test.

## Minor observations (not the cause)
1. Design smell, optional. `legacyDistance` stays in the schema permanently and duplicates data. A single-property rename, `@Attribute(originalName: "distance") var distanceKm: Double = 0` with a lightweight stage, would be simpler and would not depend on `didMigrate`. If you change this, test the new shape on a real V1 store first. Changing the shipped V2 shape also needs care, because users who already migrated hold a V2 store with the extra column.
2. `static var versionIdentifier` (SchemaV1.swift:6, SchemaV2.swift:6) may produce Swift 6 strict-concurrency warnings. `static let` is preferred. This has no runtime effect on the bug.
3. The test's V1 phase (:19-28) builds the container with no migration plan, which is correct. It does not exercise an upgrade from a store that real 1.3 users have, which is where the gap below lies.

## Could not verify from source alone
- `HikeListView` and any yearly-total code are not provided. The symptom "names and dates fine, distance 0.0, total 0" matches a view or query reading the wrong property, or a stale/default value. It also matches `didMigrate` never running. I cannot tell which.
- Whether the 1.3 release really shipped with `SchemaV1` as a `VersionedSchema` (version 1.0.0) and with a plan or container that stamped version metadata. If 1.3 used a plain unversioned `ModelContainer(for: Hike.self)`, the on-disk model hash must still equal the V1 hash for the stage to match. A mismatch would skip the custom stage and leave `distanceKm` at its default 0 while `legacyDistance` holds the real value. This fits the symptom. The "Do not edit" comment on SchemaV1 suggests it was kept faithful, but the source cannot prove it.
- Whether affected beta users hit a failed or interrupted first launch. `didMigrate` is not retried if it was missed, because the store is already at V2 afterwards.
- No build or run was done, per instructions. SwiftData runtime behavior (for example, how `originalName` plus a custom stage resolves) is inferred from documented behavior, not observed.

## Suggested next steps (diagnostic, since no source fix is justified)
- On an affected device or its store, inspect the `ZHIKE` table. Check whether `ZLEGACYDISTANCE` holds the old values while `ZDISTANCEKM` is 0. If so, the stage did not run, or the store was not recognized as V1. Then a repair pass is warranted: on launch, for hikes where `distanceKm == 0` and `legacyDistance != nil`, copy the value across and save.
- Confirm in HikeListView that distance and the total read `distanceKm`.
- Confirm the 1.3 binary's container setup (versioned or not) in git history.
- If the stage was skipped on real data, add a test that seeds a store with the exact 1.3 container code, not only `SchemaV1` through a bare `ModelContainer`.
