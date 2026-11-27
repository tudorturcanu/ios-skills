# Real-app widget review comparison

Both reports met all eight source-derived criteria on the pinned Ice Cubes LatestPosts widget. This does not establish a skill advantage. The assessment is **unblinded parent verification**: the separate blind-grading agent failed with a workspace-credit error and produced no grade. The randomized copies remain as preparation artifacts, not evidence of completed blind grading.

## Conditions and limits

- App: [Ice Cubes at 98098b9](https://github.com/Dimillian/IceCubesApp/tree/98098b9c4b5928f89f338203193c2bf40ab7f38c).
- Focused condition: frozen `widget-data-consistency` instructions and diagnostic cases in `tested-version/`.
- Comparator: [specialized WidgetKit skill at 8d90fd1](https://github.com/dpearson2699/swift-ios-skills/tree/8d90fd121a263355a4fb44fd082af1416a5c1c2a/skills/widgetkit), including its advanced reference. It is a relevant specialized comparator, not a claim about ranking.
- Same [task prompt](prompt.txt), one independent report per condition. No no-skill control, repeated runs, or cost/latency measurements.
- [Criteria](rubric.json) were prepared during the reviews before final reports. They were not preregistered before the runs. The planned blinded assessment described there did not occur.
- App source was reviewed without edits, builds, runtime tests, or authenticated operations. The parent rechecked HEAD and an empty `git status --porcelain`, and verified the original seven file hashes. Eleven files used in final verification are recorded in [verified-source-files.json](verified-source-files.json); app code is not vendored here.

## Source verification

| Criterion | Focused | Comparator | Verified boundary |
| --- | --- | --- | --- |
| Optional image failure | Pass | Pass | Provider lines 55, 64–73 and 77–89: an avatar task error reaches the empty-entry catch |
| Status error collapse | Pass | Pass | Shared loader lines 38–39 returns an empty array for any caught request error |
| Existing image fallback | Pass | Pass | View lines 72–81 already handles absent image data |
| Configured account semantics | Pass | Pass | Explicit configuration account supplies the request credentials |
| Account freshness | Pass | Pass | Entity query reads the singleton array initialized from durable storage; runtime consequences are qualified |
| Scheduling honesty | Pass | Pass | Neither report promises immediate reload or rendered removal |
| Scoped corrections | Pass | Pass | Both address the actual failure paths; no style modernization required |
| Evidence honesty | Pass | Pass | Source locations and unperformed runtime checks are disclosed |

See the pinned [provider](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesAppWidgetsExtension/LatestPostsWidget/LatestPostsWidget.swift#L36), [loader](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesAppWidgetsExtension/Shared/SharedUtils.swift#L10), [view](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesAppWidgetsExtension/Shared/PostsWidgetView.swift#L70), [account query](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesAppIntents/AppAccountEntity.swift#L25), and [account manager](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/AppAccount/Sources/AppAccount/AppAccountsManager.swift#L30). A repository-wide search found no widget reload calls. This establishes a missing explicit reload path, not a measured post-logout display duration.

The raw [focused](outputs/focused.md) and [comparator](outputs/peer.md) reports are preserved unchanged. Their original local links require the evaluation checkout; the pinned links above and below provide portable evidence. Machine-readable scores and limitations are in [grading.json](grading.json).

## Additional findings, outside the eight scored criteria

The focused review found a source-supported logout defect: [SettingsTab lines 149–158](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesApp/App/Tabs/Settings/SettingsTab.swift#L149) puts local deletion inside the optional push-subscription branch. No matching subscription means no deletion through that action. The other account-settings route handles a missing subscription but still requires a token. Neither report demonstrates this behavior on a device.

The comparator found a source-supported entity-query defect: [TimelineFilterEntity lines 26–28](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/IceCubesAppIntents/TimelineFilterEntity.swift#L26) ignores the supplied IDs and returns all four choices. Apple's [entity-query contract](https://developer.apple.com/documentation/appintents/entityquery/entities(for:)) describes resolving supplied identifiers; the report correctly avoids claiming this necessarily switches the displayed timeline.

These different findings indicate complementary coverage. They were not added to the scoring rubric after seeing the reports. The comparator also incorrectly states no AGENTS.md was found: the checkout contains `AGENTS.MD`. This is a discovery/reporting error, although its disclosed read-only work did not violate the instruction requiring builds after code edits.

## Correction caveats and resulting skill changes

Both reports recommend fresh account resolution. The parent additionally verified that [retrieveAll lines 26–39](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/AppAccount/Sources/AppAccount/AppAccount.swift#L26) calls `save()` for each decoded account. Simply reusing that helper can write an old record back while another process deletes it. This is a source-supported interleaving risk, not a reproduced race. Neither report calls out this implementation caveat.

The [push cleanup implementation](https://github.com/Dimillian/IceCubesApp/blob/98098b9c4b5928f89f338203193c2bf40ab7f38c/Packages/Env/Sources/Env/PushNotificationsService.swift#L286) also retries recursively while a subscription remains. Awaiting cleanup before local removal can delay logout under repeated non-nil responses. A recommendation to make cleanup best-effort needs bounded completion, not merely a caught error.

The revised skill now distinguishes direct network fetching from shared snapshots; separates optional enrichment from primary content; distinguishes failure from successful emptiness; preserves explicitly configured accounts; and routes to concise guidance on entity identity, read-helper side effects, logout callers, cancellation, and obsolete in-flight results. A persistent cache is an optional product decision with added invalidation responsibilities. Existing guidance about reload timing remains consistent with Apple's [widget scheduling documentation](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

The earlier diagnostic case “account changes” was too broad; it now distinguishes confirmed removal from a valid pinned account surviving a foreground switch. These are evidence-informed instruction changes. **The revised skill has not yet had an independent behavioral rerun**, so the 8/8 scores apply only to the frozen earlier version.
