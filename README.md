# Skills

Install all 13 skills from GitHub for your agent:

```sh
# Codex
npx skills add tudorturcanu/ios-skills --agent codex
# Claude Code
npx skills add tudorturcanu/ios-skills --agent claude-code
# Antigravity
npx skills add tudorturcanu/ios-skills --agent antigravity
```

Interactive showcase and walkthroughs: [iosskills.xyz](https://iosskills.xyz)

| Skill | What it helps with |
| --- | --- |
| [app-store-audit](app-store-audit/SKILL.md) | Audit App Store submission readiness and review rejections. |
| [ios-accessibility-audit](ios-accessibility-audit/SKILL.md) | Audit VoiceOver navigation, Dynamic Type, and accessible controls. |
| [ios-crash-triage](ios-crash-triage/SKILL.md) | Diagnose crashes and unexpected app terminations. |
| [ios-deeplink-doctor](ios-deeplink-doctor/SKILL.md) | Diagnose universal-link and custom URL routing failures. |
| [ios-launch-profiler](ios-launch-profiler/SKILL.md) | Measure and diagnose app launch latency. |
| [ios-localization-audit](ios-localization-audit/SKILL.md) | Check String Catalog coverage, pluralization, formatting, and layout. |
| [ios-memory-growth](ios-memory-growth/SKILL.md) | Investigate rising memory use across repeated interactions. |
| [ios-offline-sync-review](ios-offline-sync-review/SKILL.md) | Review offline caches, queued writes, and sync recovery. |
| [ios-permission-flow-tester](ios-permission-flow-tester/SKILL.md) | Verify permission prompts, authorization states, and recovery. |
| [iphone-duo-design](iphone-duo-design/SKILL.md) | Adapt, audit, and build SwiftUI and UIKit apps for iPhone Duo. |
| [storekit-entitlement-debugger](storekit-entitlement-debugger/SKILL.md) | Diagnose purchase, restoration, and entitlement inconsistencies. |
| [swiftdata-migration-checker](swiftdata-migration-checker/SKILL.md) | Verify SwiftData migrations preserve existing data. |
| [widget-data-consistency](widget-data-consistency/SKILL.md) | Diagnose stale or inconsistent WidgetKit data. |

## Verification status

Every skill has now been compared with a no-skill baseline on a held-out defect and clean-control fixture ([results](evals/heldout/RESULTS.md)): pooled 146/153 with the skill versus 146/153 without, so **no measured advantage** on source-review tasks. The table below describes the other evidence each skill has.

Skills differ in how much has been verified. "Tooling" means a bundled read-only helper with tests; "probe" means an executable synthetic check; "prose" means guidance only. None of this establishes superiority over other skills; see [research](research/competitive-review.md) and [evals](evals/).

| Skill | Evidence | Status |
| --- | --- | --- |
| ios-localization-audit | Tooling (catalog inventory, format arguments), real-catalog run | Tested; no measured agent advantage |
| ios-deeplink-doctor | Tooling (AASA inspector), routing benchmark | Tested; no-skill control also passed |
| ios-crash-triage | Tooling (.ips inventory) | Tested |
| ios-launch-profiler | Tooling (sample comparison) | Tested |
| swiftdata-migration-checker | Probe (six migration paths, run in CI on macOS) | Verified on CI |
| widget-data-consistency | Source-review comparison | Instructions not independently retested |
| ios-offline-sync-review | Method-level probe; held-out comparison vs no skill ([offline-sync-02](evals/offline-sync-02/RESULTS.md)) | No measured advantage (baseline 12/12, skill 11/12) |
| ios-permission-flow-tester | Simulator investigation | Full-library grant controls unresolved |
| storekit-entitlement-debugger | Local probe (22 of 22 checks on one iOS 27.2 run, 20 of 22 on the next); injection never produced unverified results on any path, so unverified handling is tested on synthetic inputs only | **Experimental**: real unverified results untested |
| ios-memory-growth | Tooling (generation-count classifier, synthetic example only) | Tested on synthetic inputs; not yet run on real traces |
| app-store-audit, ios-accessibility-audit, iphone-duo-design | Prose and structural validation | No executable evidence yet |

- [Engineering skills documentation](docs/ios-engineering-skills.md)
- [App Store Audit documentation](docs/app-store-audit.md)
