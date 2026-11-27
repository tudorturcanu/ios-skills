# Trailhead 1.3 -> 1.4 migration review (read-only source review)

Nothing was built or run. All claims come from the source files only.

## Verdict
There is one real defect, and it explains the reported symptom (all hikes listed, names and dates fine, every distance 0.0 km, yearly total 0, fresh installs fine).

## Schema-difference table (V1 -> V2, `Hike`)

| Property | V1 (SchemaV1.swift) | V2 (SchemaV2.swift) | Intended | What the code expresses |
|---|---|---|---|---|
| name | String (L11) | String (L11) | unchanged | unchanged |
| date | Date (L12) | Date (L12) | unchanged | unchanged |
| distance / distanceKm | `distance: Double` (L13) | `distanceKm: Double = 0` (L13) | rename | drop `distance` + add `distanceKm` (default 0) |
| notes | String = "" (L14) | String = "" (L14) | unchanged | unchanged |
| isFavorite | absent | Bool = false (L15) | add | add with default (fine) |

## Finding 1 (root cause): rename is not declared, so it migrates as drop-and-add
- Evidence: Models/SchemaV2.swift:13 declares `var distanceKm: Double = 0   // renamed from distance`. The rename exists only as a comment. There is no `@Attribute(originalName: "distance")` on the property.
- Evidence: Models/HikeMigrationPlan.swift:12-17 uses `MigrationStage.lightweight(fromVersion:toVersion:)` and a comment claiming "both changes are simple". A lightweight stage can only infer a rename from an explicit `originalName`. Without it, SwiftData sees a new property `distanceKm` (filled with its default, 0) and a removed property `distance` (data discarded).
- This matches the symptom exactly. Rows survive, so names and dates are intact. `distanceKm` takes the declared default of 0, so every hike shows 0.0 km and the yearly sum is 0. `notes` and `name` have the same stored names, so they are preserved. The `= 0` default on SchemaV2.swift:13 also hides the problem. Without it the migration would have been forced to surface an error rather than silently zero the values.
- Fresh installs are unaffected because there is no old data to lose.

Fix:
```swift
@Attribute(originalName: "distance") var distanceKm: Double = 0
```
- Keep the lightweight stage. `originalName` is the supported lightweight rename mechanism. Adding isFavorite with a default is also lightweight-compatible.
- Do not edit SchemaV1 (it is the shipped definition; the "Do not edit" comment at L4 is correct).
- Check the current SDK docs for `Attribute(originalName:)` behaviour on your minimum deployment target. I could not verify this from source alone.
- If you prefer to avoid reliance on `originalName`, use a custom stage via an intermediate schema (V1 -> V1.5 with both `distance` and `distanceKm`, copy values in `didMigrate`, then V2 dropping `distance`). That is heavier and is probably unnecessary here.

## Finding 2: the tests could not have caught this
- Tests/HikeMigrationTests.swift:9 uses `isStoredInMemoryOnly: true`. An in-memory store has no previously shipped on-disk data, so no migration runs at all.
- Tests L17-20 only assert the container builds and reports version 2.0.0. Tests L22-31 only insert and fetch a V2 record in a fresh store. Neither test uses SchemaV1 or the plan's stage against old data, so "green" says nothing about migration. QA tested only clean installs, which has the same gap.

Fix: add a migration test.
1. Create an on-disk store with `SchemaV1` (temp directory, no migration plan needed, or a V1-only container). Seed at least 2 hikes with distinct, non-zero distances (e.g. 12.5 and 7.25), different names/dates, and a non-empty `notes` on one. Assert the seed first, then save and close.
2. Make a disposable copy of the whole store bundle including `-wal`/`-shm` sidecars.
3. Open the copy with `SchemaV2` + `HikeMigrationPlan` and a non-in-memory configuration. Assert each hike (matched by name, not just count) has the exact `distanceKm`, `notes` preserved, and `isFavorite == false`.
4. Close, reopen, and assert again.
5. Prefer a fixture produced by a real 1.3 build/tag. A fixture generated from the current source tree is only a proxy.

## Finding 3 (unverifiable from source): users already on 1.4
- Beta users who already opened 1.4 have had the store migrated to V2 with distances reset. Adding `originalName` now will not restore data for them. The store is already at version 2 and no stage will run again.
- I cannot tell from source whether the old `distance` column is still physically in their SQLite file, or whether device or iCloud backups from before the update exist. Do not try to recover it by deleting or resetting their stores.
- Recommended path: ship a fix before wide release (if 1.4 is beta-only, hold the rollout). For affected beta users, ask them to restore from a pre-update backup, or investigate whether a custom recovery from the retained store is possible on a copy. Whether data is recoverable needs a copy of an affected store to inspect.

## Checked and found OK
- App/TrailheadApp.swift:12-17 builds the container with `SchemaV2` and `HikeMigrationPlan.self`, so the plan is wired into the real container. The container construction is correct.
- Models/HikeMigrationPlan.swift:4-10 lists both schemas in order and has one stage (the only upgrade path; 1.0-1.3 all share V1 per the comment at SchemaV1.swift:4, so no skipped-release path needs a separate stage).
- Version identifiers differ (1.0.0 vs 2.0.0).
- No CloudKit configuration, relationships, or uniqueness constraints appear in the supplied files, so none of those risks apply.

## Could not verify from source alone
- Actual runtime behaviour (nothing executed); the claim that the missing `originalName` causes the zeroing is inferred from SwiftData's documented rename semantics plus the exact symptom.
- Whether the shipped 1.3 build matches SchemaV1.swift (no release tag or fixture provided).
- `HikeListView` and the yearly total code are not provided. I assume they read `distanceKm`; if they did something else the display analysis would change.
- Whether SDK/OS versions in the field affect `originalName` handling; whether affected users' old data is recoverable.

## Unresolved risks
- Already-migrated beta users (Finding 3).
- No real V1 on-disk fixture or reopen test exists yet.
