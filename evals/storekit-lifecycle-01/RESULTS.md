# Local StoreKit lifecycle investigation

The retained transition run observed purchase, refund, and consumable completion on a disposable iOS 27.0 simulator with Xcode 27.1 (27A9275). **12 of 13 probe booleans were true, but the probe and overall run failed.** The verification-error control did not produce an unverified entitlement, and `xcodebuild` exceeded the runner's 300-second deadline after the XCTest assertion failed. A later fresh-purchase investigation stalled without a completed result. These are synthetic framework observations, not an agent comparison or a production billing test.

## Observed transitions

See [final report](run-observed-transitions/results.json), [build/test output](run-observed-transitions/xcodebuild.log), and [tested Swift source](run-observed-transitions/source.txt).

| Check | Evidence and interpretation |
| --- | --- |
| Local environment | Both configured products loaded; the returned non-consumable and consumable transactions reported `Xcode`. |
| Purchase | A verified premium entitlement appeared on the fourth bounded snapshot read. |
| Finish non-consumable | Premium remained verified after finishing its transaction. |
| Inject verification failure | Failed: premium stayed verified through 48 reads. No unverified result was observed. |
| Clear verification injection | Premium was verified afterward. The recorded boolean `verification_recovers` is true, but this **does not demonstrate recovery** because verification never visibly failed. |
| Refund | Premium was observed before refund, then absent from both verified and unverified sets on the second bounded read. |
| Faulty reducer control | A grow-only union retained premium after the refund snapshot removed it. The fixture exposed stale access. |
| Consumable | Excluded from current entitlements; its ID was observed in unfinished transactions before finish and absent afterward. This does not test a durable consumable balance. |

The bounded observations poll at 100 ms with a five-second deadline between enumerations. A sequence that itself never completes is bounded by the enclosing XCTest/runner limits, not by that polling loop. Snapshot reconciliation does not prove `Transaction.updates` listener delivery. No account change, cancellation, subscription, server notification, reinstall, real purchase, or customer billing behavior was exercised.

## Retained unsuccessful attempts

All ten attempts remain available, with source hashes mapped by [run-index.json](run-index.json). Historical reports are preserved without relabeling failed runs as successes.

| Directory | Outcome |
| --- | --- |
| `run` | SDK header deprecation prevented compilation; no simulator created. |
| `run-header-adjustment` | Compilation still failed; also exposed the installed SDK's `UInt` refund identifier. No simulator created. |
| `run-local-session` | Standalone app compiled; local session did not complete within 120 seconds. |
| `run-hosted` | Hosted test target still failed on the SDK header diagnostic. |
| `run-hosted-shared-flags` | Hosted app ran on iOS 26.3.1; products did not load and purchase returned `notEntitled`. |
| `run-hosted-signed` | Ad hoc signing did not resolve that setup result. |
| `run-active-configuration` | Scheme configuration added; wrapper timed out without preserving the test log or final probe result. No product conclusion is supported. |
| `run-ios27` | Products loaded, but immediate snapshots missed purchase and unfinished state. “Refund removed” and “finished removed” booleans were vacuous empty-to-empty checks. They are not accepted transition evidence. Wrapper timed out. |
| `run-observed-transitions` | Required preconditions and bounded observations produced the transitions above. Verification control and overall run remained failed; wrapper timed out. |
| `run-fresh-verification` | Extended the probe with an app-facing purchase under verification injection and same-transaction recovery checks. Stalled in `fresh_purchase_verification`; no completed probe JSON was retained. The log records a restart after unexpected exit/crash/timeout without resolving which cause. Wrapper timed out. No verification or recovery assertion is claimed. |

Each of the eight created simulators has a recorded successful deletion. The first two `cleanup_deleted: false` values refer to compilation failures before simulator creation. Device absence was also independently checked against `simctl list devices` after completion. Existing user simulators were not modified.

The current probe renames the misleading `verification_recovers` boolean to `verified_after_injection_reset`. The new recovery check requires an observed unverified purchase followed by a verified transaction with the same ID. Since the fresh-purchase run never completed, those checks remain unexercised. Subsequent checkpoint changes write completed observations and checks into `progress.json`, and the runner retains them under `partial_probe` on interruption. These checkpoint changes passed Swift type checking; their stalled-runtime behavior has not yet been rerun. Partial checkpoints are never treated as a completed probe.

## Changes informed by the investigation

The StoreKit skill now requires distinct verified, unverified, interrupted, and obsolete snapshots; serial mutations of a shared StoreKit test environment; observed pre-transition states; and evidence that failure injection actually reached the path under test. These instructions are not themselves runtime-tested application code. The verification-failure and recovery requirements remain unexercised by this probe.

The hosted runner now retains timeout output, terminates its owned process group, and reads partial probe evidence before deleting its simulator. Three Python subprocess tests verify ordinary output, timeout-output retention, and recording checked failures. Evidence validation separately checks frozen input hashes and the final transition claims against recorded observations.

## Reproduction

Requires macOS, Xcode, and the specified installed simulator runtime/device type. From the repository root, use a new output directory:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 evals/storekit-lifecycle-01/reproduce_hosted.py \
  --runtime com.apple.CoreSimulator.SimRuntime.iOS-27-0 \
  --device-type com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  --output /tmp/storekit-lifecycle-new-run
```

This creates and deletes its own simulator, uses two synthetic local products, and needs no App Store account. The retained outcome is a **nonzero exit**, not a green suite. Runtime changes may produce a different result; keep new evidence separate. The older standalone `reproduce.py` is retained for investigation and has no successful end-to-end run here.

Relevant primary contracts: [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [SKTestSession](https://developer.apple.com/documentation/storekittest/sktestsession), and [configuring local StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode). The observed failure to inject an error into a cached entitlement does not establish an SDK defect or the behavior of a fresh purchase verification.
