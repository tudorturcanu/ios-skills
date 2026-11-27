# Real-app posting recovery probe

The pinned Ice Cubes posting coordinator loses partial-completion information when a later thread post fails. Its recovery helper inserts only the root text, including when that root already succeeded. A five-case Swift probe reproduced these method-level outcomes. This is a parent-led source investigation and executable probe, **not an independent agent evaluation or an end-to-end app test**.

## Source and execution boundary

App commit: [98098b9c4b5928f89f338203193c2bf40ab7f38c](https://github.com/Dimillian/IceCubesApp/tree/98098b9c4b5928f89f338203193c2bf40ab7f38c). The checkout remained unchanged. [Source hashes](source-files.json) pin the five files used in the investigation; app code is not vendored into this repository.

The [reproducer](reproduce.py) verifies the commit and complete source-file hash, then extracts `saveDraftIfNeeded` (lines 187–191) and `postAllStatus` (lines 213–225) from [ToolbarItems.swift](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/StatusKit/Sources/StatusKit/Editor/ToolbarItems.swift#L187). Those unchanged methods compile in a temporary harness with Swift 6 language mode and warnings as errors. The retained result records the actual Swift compiler version.

[Harness doubles](harness.swift) supply posting responses, editor values, and draft insertions. The harness models the nil-result dispatch from the UI error handler at lines 166–167; it does not compile that SwiftUI handler. There are no real network requests, SwiftData saves, app builds, device runs, or restart tests. Temporary extracted code is removed when execution ends.

## Observed behavior

| Scenario | Acknowledged by fake posting | Aggregate result | Draft insertion |
| --- | --- | --- | --- |
| All three posts succeed | Root, reply 1, reply 2 | Reply 2 | None |
| Root fails | None | nil | Root text only |
| Reply 1 fails | Root | nil | Root text only |
| Reply 2 fails | Root, reply 1 | nil | Root text only |
| Blank root fails | None | nil | None |

The success control also verifies reply 1 targets the root and reply 2 targets reply 1. Failure stops subsequent requests, which is valid for dependent thread replies. The issue is recovery: the caller does not receive the acknowledged prefix, and the inserted draft omits failed and unattempted reply text. Root failure also omits planned replies. A blank text guard skips insertion; whether that branch represents a valid media-only post requires additional integration testing.

The UI closes before awaiting posting (ToolbarItems lines 132–145), then reports saved-to-drafts on failure (lines 166–183). The [Draft model](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/Models/Sources/Models/SwiftData/Draft.swift#L5) stores text and creation date, not the full thread or posting parameters. The probe observes insertion calls, not disk durability. It does not prove permanent loss on every real failure or demonstrate a duplicate server publication.

## Retry contract investigation

[PostingService](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/StatusKit/Sources/StatusKit/Editor/Services/PostingService.swift#L58) submits new posts through the generic client. The [request builder](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/NetworkClient/Sources/NetworkClient/MastodonClient.swift#L117) sets authentication and JSON content headers, with no idempotency key on this path. Source inspection does not demonstrate an automatic status retry; a user's resubmission after an ambiguous failure is a separate operation in the current flow.

Mastodon's [official status-creation contract](https://docs.joinmastodon.org/methods/statuses/#create), consulted during this investigation, documents an optional idempotency key retained for up to one hour. Adding a stable key can help within the applicable server contract; it does not establish safe replay after indefinite offline storage. No server version or deployment behavior was verified here. The contract must not be generalized to the app's separate media upload endpoint.

## Changes to the skill

The pre-change instructions are preserved in `inspected-version/`. No independent agent run was performed. The revised skill now requires checking per-step acknowledgments and recoverable suffixes, following “saved” messages to actual durable writes, and verifying operation-key scope, payload binding, and server retention windows. A new reference explains why a new key per retry and a content hash shared across intentional repeated actions can both be wrong.

The app was not patched. A scoped app correction would retain completed server IDs and recover the unresolved items with their payload and reply dependencies. An ambiguous step needs server-supported reconciliation or deduplication; it cannot safely be treated as definitely unsent. These recommendations remain unimplemented and untested in the full app. The revised skill has not yet had a comparative behavioral evaluation.

## Reproduce

Provide a local checkout at the pinned commit and a new output directory; Swift must be installed:

```sh
python3 evals/offline-recovery-01/reproduce.py \
  --checkout /absolute/path/to/IceCubesApp \
  --output /tmp/ice-cubes-recovery-results
```

The script requires exact source bytes, writes only temporary build files and the new output directory, and checks source/status afterward. It exits nonzero if the fixed observations differ. Matching [expected observations](expected-observations.json) means the probe reproduced the recorded behavior; it does **not** mean the app passes a correctness test. [Retained results](run/results.json) explicitly record `app_correctness_passed: false` and the scope limits.
