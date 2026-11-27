# Diagnose migration failures

| Evidence | Investigate next | Avoid |
| --- | --- | --- |
| Fresh store opens; shipped store fails | Original schema metadata, migration-plan wiring, exact old fixture and new container | Calling fresh-store success a migration pass |
| Renamed values become defaults | Stored property identity and rename mapping; nondefault historical fixture values | Assuming record counts prove value preservation |
| New uniqueness constraint fails | Existing duplicates and explicit conflict-resolution policy | Silently deleting records to force opening |
| Relationships lose members | Model identities, inverse definitions, delete rules, and per-relationship assertions | Testing only top-level counts |
| Failure only on skipped release | Every supported source schema's path through configured stages | Testing adjacent upgrades alone |

A high-value fixture uses at least two records with distinct nondefault values and a relationship between them. Reopen after migration and assert the original identities and intended relationship remain. Adapt this example to the schema change; do not impose it on models without relationships. Keep the failed copy for diagnostics while leaving the pristine fixture untouched.
