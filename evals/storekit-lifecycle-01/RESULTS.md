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

## Bounded fresh purchase (eleventh attempt, iOS 27.2)

The fresh-purchase call now runs under a 20-second bound (`boundedPurchase` in `Probe.swift`), so a stall is recorded as evidence instead of ending the run without a result. On iOS 27.2 the run completed with a nonzero exit: `product.purchase(confirmIn:)` with an injected `.invalidSignature` verification error did not return within 20 seconds (`fresh_purchase_returned_within_bound` is false). The three dependent checks (`fresh_purchase_is_unverified`, `fresh_same_id_verification_recovers`, `unverified_is_not_an_empty_snapshot`) are therefore false because their precondition was never observed, not because recovery failed. The other 13 checks were true, and the simulator was deleted. Retained in [run-bounded-purchase](run-bounded-purchase/results.json).

This is the first run with a completed result, and it narrows the open question: injected verification failure on a fresh purchase stalls in this configuration. It does not show whether that is an SDK behavior, a test-host limitation, or a probe defect, and it still leaves verification-failure handling and recovery unexercised.

## Injection behavior observed, unverified handling tested synthetically (twelfth attempt, iOS 27.2)

This run completed with exit 0, 22 of 22 checks true, and the simulator deleted ([run-injection-observed](run-injection-observed/results.json)). It also changes what the probe claims. Across all paths tried, `SKTestSession` verification injection (`.invalidSignature`) never produced an `.unverified` result:

- **Cached entitlement:** an already-purchased nonconsumable stayed verified for 45 polling attempts while injection was set (`cached_entitlement_unaffected_by_injection`).
- **New transaction via the test session:** `buyProduct` returned transaction 2, but it was absent from both `Transaction.latest(for:)` and `Transaction.all` while injection was set, and appeared verified with the same ID once injection was cleared (`injected_new_transaction_hidden_from_history`, `injected_same_id_visible_verified_after_reset`).
- **App-facing `Product.purchase`:** in this ordering it returned a verified result for transaction 2 despite injection. In the earlier ordering, without the test-session purchase before it, the same call did not return within 20 seconds. The outcome depends on prior state, so neither is a stable negative result.

The earlier `fresh_purchase_is_unverified`, `fresh_same_id_verification_recovers`, and `unverified_is_not_an_empty_snapshot` checks were removed because their precondition cannot be produced here; the retained earlier runs still record them as false. The practical consequence for the skill: an empty or missing snapshot during a verification problem is not revocation evidence, which is the hazard the skill already warns about.

Unverified handling is covered only by four synthetic checks on `reconcileEntitlements` (unverified never grants, never revokes, only a complete empty snapshot revokes, an incomplete snapshot changes nothing). These test the decision rule on hand-built inputs, not StoreKit output, and not any app's own code. Whether real unverified results (for example a tampered signature on a device or sandbox) are handled correctly remains untested.

## Updates stream under injection, and run-to-run variance (thirteenth attempt, iOS 27.2)

This run added a `Transaction.updates` listener started before injection, to test the one path not yet tried. With `.invalidSignature` set, `buyProduct` returned transaction 2 and the listener received **no entries within 5 seconds**; the transaction was again absent from `latest` and `all`. So none of cached entitlements, history, the updates stream, or the app-facing purchase produced an `.unverified` result in this environment ([run-updates-stream](run-updates-stream/results.json)).

The run completed with a nonzero exit: 20 of 22 checks true. `fresh_purchase_returned_within_bound` was false (the app-facing purchase did not return within 20 seconds, as in the earlier stall) and `injected_same_id_visible_verified_after_reset` was false (the transaction was not seen verified within 5 seconds of clearing injection). The previous run, without the listener, passed 22 of 22. The probe is therefore **not stable run to run**; whether the listener caused the difference or it is ordinary variance was not isolated. The headline claim stays as in the previous section: injection hides or stalls rather than flagging unverified, and unverified handling is exercised only on synthetic inputs.
