# iOS Engineering Skills

Ten focused agent skills for diagnosing, fixing, and verifying iOS behavior. Each skill is independently installable and includes workflow-specific evidence requirements. They support SwiftUI and UIKit where applicable without requiring another skill collection.

## Install

Inspect available skills from GitHub:

```sh
npx skills add tudorturcanu/ios-skills --list
```

Install the collection for Codex in your current project:

```sh
npx skills add tudorturcanu/ios-skills --skill '*' --agent codex
```

Or select one:

```sh
npx skills add tudorturcanu/ios-skills --skill ios-deeplink-doctor --agent codex
```

Add `--global` only if you want installation across projects; no npm package publication is required. When installing from a local checkout, replace `tudorturcanu/ios-skills` with `.` or the checkout path. See the [Skills CLI](https://github.com/vercel-labs/skills) for current requirements and options.

## Skills

| Skill | Use it for |
| --- | --- |
| [ios-deeplink-doctor](../ios-deeplink-doctor/SKILL.md) | Diagnose and fix iOS universal-link and custom URL routing failures across cold launch, authentication, scenes, tabs, and sheets |
| [ios-accessibility-audit](../ios-accessibility-audit/SKILL.md) | Audit or fix accessibility in iOS SwiftUI and UIKit flows, including VoiceOver, Dynamic Type, focus, contrast, and motion |
| [swiftdata-migration-checker](../swiftdata-migration-checker/SKILL.md) | Review or implement SwiftData schema migrations and verify preservation of existing on-disk data across supported upgrade paths |
| [storekit-entitlement-debugger](../storekit-entitlement-debugger/SKILL.md) | Diagnose and fix StoreKit purchase and entitlement inconsistencies, including restoration, pending purchases, renewal, refund, revocation, and account changes |
| [ios-localization-audit](../ios-localization-audit/SKILL.md) | Audit or fix iOS localization extraction, String Catalog coverage, pluralization, formatting, RTL behavior, and text expansion |
| [ios-crash-triage](../ios-crash-triage/SKILL.md) | Triage iOS crash reports and termination logs against matching source and symbols |
| [ios-launch-profiler](../ios-launch-profiler/SKILL.md) | Measure and diagnose iOS application startup using launch traces, metrics, and matching source, then verify targeted improvements |
| [ios-offline-sync-review](../ios-offline-sync-review/SKILL.md) | Review or fix iOS offline caching and synchronization correctness across queued writes, retries, conflicts, process death, and account changes |
| [ios-permission-flow-tester](../ios-permission-flow-tester/SKILL.md) | Review or fix iOS permission lifecycles and recovery for camera, microphone, photos, location, notifications, and other protected resources |
| [widget-data-consistency](../widget-data-consistency/SKILL.md) | Diagnose and fix stale or inconsistent WidgetKit content across shared storage, timelines, reload requests, configuration, and account changes |

## Usage

Ask for the outcome, for example: “Use $ios-deeplink-doctor to fix a product link that loses its destination after login.” Audit requests produce findings; fix requests permit scoped changes. Skills retain the project's architecture and deployment target and consult current primary documentation for SDK-dependent behavior.

A source-only review does not establish runtime correctness. Device access, matching symbols, historical stores, StoreKit environments, or backend contracts may be needed for particular conclusions. Skills report those gaps explicitly.

## Validation

```sh
python3 scripts/validate.py
python3 scripts/validate_evidence.py
python3 -m unittest discover -s tests -v
```

This checks packaging, metadata, local reference links, and unresolved scaffolding using only Python's standard library. It does not prove an agent will follow the workflow correctly. Behavioral evaluation cases and observable success criteria are in [tests/scenarios.md](../tests/scenarios.md). Run them against disposable fixtures when evaluating model behavior; they are not claimed as executed merely because structural validation passes.

## Diagnostic tools

Five skills bundle Python 3 helpers with no third-party Python dependencies. The catalog, AASA, crash, and launch helpers inspect supplied files; the migration probe creates disposable stores and build outputs:

- `ios-localization-audit`: inventory requested locales and nested translation states; inspect selected flat format strings for declared argument-type changes.
- `ios-deeplink-doctor`: compare a local AASA file against signed application identity and domain entitlements.
- `ios-crash-triage`: extract structural evidence from single- or two-document JSON crash reports.
- `ios-launch-profiler`: compare supplied measurements only within matching conditions, preserving separate first-frame and readiness intervals.
- `swiftdata-migration-checker`: execute a synthetic on-disk migration probe with separate processes and a silent-data-loss negative control (macOS/Xcode required).

Each skill documents its command, supported inputs, exit codes, and limitations. Helpers produce evidence for an investigation; they do not certify an app or replace device verification.

The [competitive review](../research/competitive-review.md) records what we learned from leading skills, pinned source revisions, and the remaining evaluation gates. The Python test suite currently covers 90 cases, including tool behavior, subprocess handling, and retained-evidence integrity; agent-level superiority has not been established.

The first [independent localization comparison](../evals/localization-01/RESULTS.md) was a tie: original, revised, and SwiftUI Pro each met all nine criteria on one synthetic case. Broader behavioral validation remains necessary.

The [executable routing comparison](../evals/deeplink-01/RESULTS.md) also tied: our skill, SwiftUI Pro, and a no-skill control each passed all 32 fixed checks. It validates fixes but does not demonstrate incremental skill value.

The [SwiftData probe results](../evals/migration-probe-01/RESULTS.md) verify six real on-disk synthetic migration paths and detect a deliberately broken rename. These are framework integration checks on this Mac, not evidence that a user's historical app stores migrate correctly.

The [format argument checker verification](../evals/format-arguments-01/RESULTS.md) includes 19 focused tests and eight Foundation formatting examples. Valid positional reordering is accepted; complex plural/substitution syntax is explicitly deferred.

The [real-app catalog validation](../evals/real-catalog-01/RESULTS.md) processed a pinned Ice Cubes catalog with 741 entries and 19 locales. It led to a tested reduction in empty-fallback review noise; six selected format comparisons passed and a complex substitution was deferred. The app checkout remained unchanged.

The [real-app widget review comparison](../evals/widget-review-01/RESULTS.md) found both our skill and a specialized WidgetKit comparator met eight source-review criteria, with different additional findings. Grading was unblinded after an independent grading run failed. The results informed narrower failure-boundary guidance; the revised instructions have not yet been independently retested.

The [posting recovery probe](../evals/offline-recovery-01/RESULTS.md) executes two pinned Ice Cubes methods with test doubles. Five cases expose incomplete recovery after partial thread publication and inform the offline-sync skill's guidance on partial completion and retry identity. This is a method-level probe, not a full-app or comparative agent test.

The [photo permission investigation](../evals/photo-permissions-01/RESULTS.md) combines app source review with a synthetic simulator app. Picker presentation and add-only separation passed, while full-library simulator-grant controls remained unresolved across three attempts. The skill now distinguishes operation scopes and verifies framework status instead of trusting a successful privacy command.

The [StoreKit lifecycle investigation](../evals/storekit-lifecycle-01/RESULTS.md) observed local purchase, refund, and consumable completion transitions and detected a faulty grow-only entitlement reducer. Twelve of thirteen probe checks were true, but verification-error injection failed and the test runner timed out. A subsequent fresh-purchase investigation stalled without a completed result. The skill now requires observed transition preconditions and distinguishes successful error injection calls from actual failure/recovery evidence. All ten attempts are retained; this is not a passing StoreKit suite or a comparative agent result.
