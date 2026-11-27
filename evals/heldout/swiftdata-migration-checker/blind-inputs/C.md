# Trailhead 1.4 migration review (project)

## Verdict
One real defect, and it matches the reported symptom: the V1 to V2 lightweight migration does not carry `distance` over to `distanceKm`. The tests do not cover migration from an existing V1 store, so they stay green.

## Finding 1 (high): rename is not declared, so the lightweight migration drops the data
- Models/SchemaV2.swift:13 declares `var distanceKm: Double = 0   // renamed from distance` with no `@Attribute(originalName: "distance")`.
- Models/SchemaV1.swift:13 has `var distance: Double`.
- Models/HikeMigrationPlan.swift:12-17 uses `MigrationStage.lightweight(...)` and its comment says "renames `distance` to `distanceKm`... lightweight is enough".
- A lightweight migration infers changes only from the two model definitions. A new property name with no `originalName` is seen as "remove `distance`, add `distanceKm`". The added column takes its declared default, `= 0` (SchemaV2.swift:13), and the old `distance` values are discarded.
- This fits the report in CONTEXT.md: rows survive (name, date, notes unchanged, so the same-named attributes migrate), every hike shows 0.0 km, and the yearly total is 0. Fresh installs are fine because no migration runs.
- The default `= 0` on `distanceKm` makes the add succeed silently instead of failing, which hides the problem.

Suggested change (verify against a real V1 store before shipping):
1. Add the original name: `@Attribute(originalName: "distance") var distanceKm: Double = 0` in SchemaV2.Hike. Lightweight migration then performs a rename. `isFavorite` stays a plain additive field with a default.
2. Alternative if you prefer explicit control: replace the lightweight stage with `MigrationStage.custom(fromVersion:toVersion:willMigrate:didMigrate:)`. That approach needs an intermediate schema, because `distanceKm` and `distance` cannot both be copied inside one same-named `Hike` model. Option 1 is simpler.

## Finding 2 (high): the tests cannot catch this
- Tests/HikeMigrationTests.swift:7-15 builds an in-memory container from SchemaV2 with the plan, but never creates a store at V1 first, so no migration runs.
- `containerBuildsWithMigrationPlan` (line 17) only checks the schema version, which is trivially true.
- `storesAndFetchesHike` (line 22) inserts a V2 object directly and reads it back. This is the same path as a clean install.
- Suggested test: open a store at a temporary on-disk URL (not `isStoredInMemoryOnly`) with `Schema(versionedSchema: SchemaV1.self)` and no migration plan. Insert `SchemaV1.Hike(name: "Ridge", date: ..., distance: 12.5)`, save, and release the container. Then reopen the same URL with SchemaV2 plus `HikeMigrationPlan`, fetch `SchemaV2.Hike`, and assert `distanceKm == 12.5` and `isFavorite == false`. This test fails against the current code and passes after Finding 1 is fixed. Delete the store files in cleanup.
- QA only tested clean installs, so a manual upgrade test from a 1.3 build with real data should be added to the release checklist.

## Not a problem
- App/TrailheadApp.swift:12-17 correctly passes `HikeMigrationPlan.self` and a V2 schema. `schemas` and `stages` in the plan (lines 4-10) are ordered and complete.
- `typealias Hike = SchemaV2.Hike` (TrailheadApp.swift:4) is fine.
- `notes` and `name`/`date` are unchanged between V1 and V2, and the new `isFavorite` has a default, so those parts migrate correctly.
- Minor style point: `static var versionIdentifier` (both schema files) is mutable shared state, and Swift 6 strict concurrency may warn. Using `static let` is the usual form. This is unrelated to the bug.

## Could not verify from source alone
- That no `HikeListView` or other view files exist or use a different property. They were not provided, but the symptom is explained by the model files alone.
- The exact runtime behaviour of the migration. I did not build or run anything, so the diagnosis rests on documented SwiftData lightweight-migration semantics, not an observed run.
- Recovery for beta users who already upgraded to 1.4. Their store already has the `distance` column dropped, so their old distances are probably gone from the live store. Check for a pre-upgrade backup (device or iCloud backup, or a store copy the app may have made). Whether adding `originalName` now helps already-migrated stores, or whether it needs a new SchemaV3 stage, depends on how the store's recorded model hashes compare, which cannot be determined from source. Test this on a device that has already upgraded before choosing between editing V2 and adding V3.
- Whether a rename detected through `originalName` combined with a changed default behaves identically across OS versions. Test on the minimum supported OS.
