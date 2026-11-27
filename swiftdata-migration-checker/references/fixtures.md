# Migration fixture protocol

1. Identify the source release commit/schema and the oldest supported direct upgrade. Preserve shipped schema definitions.
2. Use a small fixture-producing app or test target compiled with that schema. Insert records that expose the specific change: renamed nondefault values, duplicate unique candidates, missing optional values, relationship cycles or deletions where valid.
3. Assert that the seed contains the intended values and relationship graph; do not treat whatever was written as the oracle. Save and close the store. Keep a coherent store bundle including required sidecars. Retain a pristine fixture; migrate disposable copies only. Avoid real customer data.
4. Open the copy with the new schema and actual migration plan. Record errors rather than replacing or deleting the failed store.
5. Assert expected identifiers, semantic field values, relationship membership, counts, and documented transformations. Reopen and assert again to detect unsaved changes.
6. Repeat for every supported starting release, including skipped-release upgrades. A fresh-store test is a separate case.

Record fixture provenance, SDK/OS, source and destination versions, path taken, expected transformation, and actual assertions. In-memory stores cannot prove compatibility with a previously shipped on-disk store. CloudKit synchronization and deployment require separate evidence.
